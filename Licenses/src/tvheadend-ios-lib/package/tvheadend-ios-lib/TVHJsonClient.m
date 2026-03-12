//
//  TVHJsonClient.m
//  TVHeadend iPhone Client
//
//  Created by Luis Fernandes on 2/22/13.
//  Copyright 2013 Luis Fernandes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import "TVHServerSettings.h"
#import "TVHJsonClient.h"
#import "TVHJsonUTF8AutoCharsetResponseSerializer.h"
#import "TVHJsonUTF8HackResponseSerializer.h"

#ifdef ENABLE_SSH
#import "SSHWrapper.h"
#endif

// ---------------------------------------------------------------------------
// Private interface
// ---------------------------------------------------------------------------

@interface TVHJsonClient () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURL *baseURL;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;

// Compound response-serializer chain (used in order; first success wins).
@property (nonatomic, strong) NSArray<id<TVHResponseSerialization>> *responseSerializers;

#ifdef ENABLE_SSH
@property (nonatomic, strong) SSHWrapper *sshPortForwardWrapper;
#endif

@end

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

@implementation TVHJsonClient

#pragma mark - Init

- (instancetype)init {
    [NSException raise:@"Invalid Init" format:@"TVHJsonClient requires TVHServerSettings"];
    return nil;
}

- (instancetype)initWithSettings:(TVHServerSettings *)settings {
    NSParameterAssert(settings);
    self = [super init];
    if (!self) { return nil; }

    _baseURL  = settings.baseURL;
    _username = settings.username;
    _password = settings.password;

#ifdef ENABLE_SSH
    if (settings.sshPortForwardHost.length > 0) {
        _readyToUse = NO;
        [self setupPortForwardToHost:settings.sshPortForwardHost
                           onSSHPort:[settings.sshPortForwardPort intValue]
                        withUsername:settings.sshPortForwardUsername
                        withPassword:settings.sshPortForwardPassword
                         onLocalPort:[TVHS_SSH_PF_LOCAL_PORT intValue]
                              toHost:settings.sshHostTo
                        onRemotePort:[settings.sshPortTo intValue]];
    } else {
        _readyToUse = YES;
    }
#else
    _readyToUse = YES;
#endif

    // Build URLSession with self as delegate for auth-challenge handling.
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPShouldSetCookies = NO;

    // Delegate queue: nil → default serial delegate queue (callbacks on bg thread).
    // success/failure blocks are always dispatched to main queue explicitly.
    _session = [NSURLSession sessionWithConfiguration:config
                                             delegate:self
                                        delegateQueue:nil];

    // Build compound response-serializer chain.
    _responseSerializers = @[
        [TVHJsonUTF8AutoCharsetResponseSerializer serializer],
        [TVHJsonUTF8HackResponseSerializer serializer],
    ];

    return self;
}

- (void)dealloc {
    [_session invalidateAndCancel];
    [self stopPortForward];
}

#pragma mark - URL Construction

/// Build an absolute NSURL from the given API path (no leading slash needed)
/// and an optional dictionary of query parameters.
- (NSURL *)buildURLForPath:(NSString *)path parameters:(NSDictionary *)parameters {
    // Ensure single slash between base URL and path.
    NSString *base = [self.baseURL absoluteString];
    if ([base hasSuffix:@"/"]) {
        base = [base substringToIndex:base.length - 1];
    }
    NSString *pathWithSlash = [path hasPrefix:@"/"] ? path : [@"/" stringByAppendingString:path];
    NSString *urlString = [base stringByAppendingString:pathWithSlash];

    if (parameters.count == 0) {
        return [NSURL URLWithString:urlString];
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        [items addObject:[NSURLQueryItem queryItemWithName:[key description]
                                                    value:[val description]]];
    }];
    components.queryItems = items;
    return components.URL;
}

/// Encode a parameter dictionary as application/x-www-form-urlencoded data.
- (NSData *)encodedFormBody:(NSDictionary *)parameters {
    if (parameters.count == 0) { return [NSData data]; }
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSMutableArray<NSString *> *pairs = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        NSString *k = [[key description] stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        NSString *v = [[val description] stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", k, v]];
    }];
    return [[pairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Response Parsing

/// Compound-serializer parse: standard NSJSONSerialization first,
/// then the two custom serializers in order. Returns first successful parse.
- (id)parseData:(NSData *)data
       response:(NSURLResponse *)response
          error:(NSError *__autoreleasing *)outError {

    if (!data || data.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSURLErrorDomain
                                           code:NSURLErrorZeroByteResource
                                       userInfo:@{NSLocalizedDescriptionKey: @"Empty response body"}];
        }
        return nil;
    }

    // 1. Standard JSON parse (fastest, handles well-formed UTF-8 JSON).
    NSError *stdError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&stdError];
    if (jsonObject && !stdError) { return jsonObject; }

    // 2. Try encoding-heuristic + control-char-strip serializer.
    for (id<TVHResponseSerialization> serializer in self.responseSerializers) {
        NSError *serError = nil;
        id result = [serializer responseObjectForResponse:response data:data error:&serError];
        if (result && !serError) { return result; }
    }

    // All parsers failed — report original JSON error.
    if (outError) { *outError = stdError; }
    return nil;
}

#pragma mark - Not-Ready Error

- (void)dispatchNotReadyError:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSLog(@"TVHJsonClient: not ready or not reachable yet, aborting…");
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: NSLocalizedString(@"Server not reachable or not yet ready to connect.", nil)
    };
    NSError *error = [NSError errorWithDomain:@"TVHJsonClient"
                                         code:NSURLErrorNotConnectedToInternet
                                     userInfo:userInfo];
    if (failure) {
        dispatch_async(dispatch_get_main_queue(), ^{ failure(nil, error); });
    }
}

#pragma mark - Public API

- (NSURLSessionDataTask *)getPath:(NSString *)path
                       parameters:(NSDictionary *)parameters
                          success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                          failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    if (!self.readyToUse) {
        [self dispatchNotReadyError:failure];
        return nil;
    }

    NSURL *url = [self buildURLForPath:path parameters:parameters];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) {
            if (failure) {
                dispatch_async(dispatch_get_main_queue(), ^{ failure(nil, networkError); });
            }
            return;
        }
        NSError *parseError = nil;
        id result = [self parseData:data response:response error:&parseError];
        if (parseError || !result) {
            if (failure) {
                dispatch_async(dispatch_get_main_queue(), ^{ failure(nil, parseError); });
            }
        } else {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{ success(nil, result); });
            }
        }
    }];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                           success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                           failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    if (!self.readyToUse) {
        [self dispatchNotReadyError:failure];
        return nil;
    }

    NSURL *url = [self buildURLForPath:path parameters:nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody   = [self encodedFormBody:parameters];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) {
            if (failure) {
                dispatch_async(dispatch_get_main_queue(), ^{ failure(nil, networkError); });
            }
            return;
        }
        NSError *parseError = nil;
        id result = [self parseData:data response:response error:&parseError];
        if (parseError || !result) {
            if (failure) {
                dispatch_async(dispatch_get_main_queue(), ^{ failure(nil, parseError); });
            }
        } else {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{ success(nil, result); });
            }
        }
    }];
    [task resume];
    return task;
}

#pragma mark - NSURLSessionDelegate (Auth Challenge)

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {

    NSString *method = challenge.protectionSpace.authenticationMethod;

    // Server-trust: default handling (no custom SSL pinning).
    if ([method isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    // Abort on repeated failures (wrong credentials).
    if (challenge.previousFailureCount > 0) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    // HTTP Basic / Digest.
    if ([method isEqualToString:NSURLAuthenticationMethodHTTPDigest] ||
        [method isEqualToString:NSURLAuthenticationMethodHTTPBasic]) {
        if (self.username.length > 0) {
            NSURLCredential *cred = [NSURLCredential credentialWithUser:self.username
                                                               password:self.password
                                                            persistence:NSURLCredentialPersistenceForSession];
            completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
        } else {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
        return;
    }

    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

#pragma mark - SSH Port Forward (unchanged, #ifdef guarded)

- (void)setupPortForwardToHost:(NSString *)hostAddress
                     onSSHPort:(unsigned int)sshHostPort
                  withUsername:(NSString *)username
                  withPassword:(NSString *)password
                   onLocalPort:(unsigned int)localPort
                        toHost:(NSString *)remoteIp
                  onRemotePort:(unsigned int)remotePort {
#ifdef ENABLE_SSH
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSError *error;
        self.sshPortForwardWrapper = [[SSHWrapper alloc] init];
        [self.sshPortForwardWrapper connectToHost:hostAddress
                                            port:sshHostPort
                                            user:username
                                        password:password
                                           error:&error];
        if (!error) {
            self.readyToUse = YES;
            [self.sshPortForwardWrapper setPortForwardFromPort:localPort
                                                       toHost:remoteIp
                                                       onPort:remotePort];
            self.readyToUse = NO;
        } else {
            NSLog(@"TVHJsonClient SSH PF error: %@", error.localizedDescription);
        }
    });
#endif
}

- (void)stopPortForward {
#ifdef ENABLE_SSH
    if (!self.sshPortForwardWrapper) { return; }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self.sshPortForwardWrapper closeConnection];
        self.sshPortForwardWrapper = nil;
    });
#endif
}

@end
