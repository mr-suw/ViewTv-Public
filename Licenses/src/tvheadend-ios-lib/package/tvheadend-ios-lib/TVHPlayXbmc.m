//
//  TVHPlayXbmc.m
//  TvhClient
//
//  Created by Luis Fernandes on 27/10/13.
//  Copyright (c) 2013 Luis Fernandes.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#ifdef ENABLE_XBMC

#import "TVHPlayXbmc.h"
#include <arpa/inet.h>

#define SERVICE_TYPE @"_xbmc-jsonrpc-h._tcp"
#define DOMAIN_NAME @"local"
#define DISCOVER_TIMEOUT 5.0f

@interface TVHPlayXbmc() <NSNetServiceDelegate,  NSNetServiceBrowserDelegate> {
    NSMutableArray *services;
    NSMutableDictionary *foundServices;
    BOOL searching;
    NSNetServiceBrowser *netServiceBrowser;
    NSTimer *timer;
}
@end

@implementation TVHPlayXbmc

+ (TVHPlayXbmc*)sharedInstance {
    static TVHPlayXbmc *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHPlayXbmc alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:__sharedInstance
                                                 selector:@selector(appWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:__sharedInstance
                                                 selector:@selector(appWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    });
    return __sharedInstance;
}

- (void)appWillResignActive:(NSNotification*)note {
    [self stopDiscovery];
}

- (void)appWillEnterForeground:(NSNotification*)note {
    [self startDiscover];
}

- (id)init {
    self = [super init];
    if (self) {
        services = [[NSMutableArray alloc] init];
        foundServices = [[NSMutableDictionary alloc] init];
        netServiceBrowser = [[NSNetServiceBrowser alloc] init];
        
        [self startDiscover];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    services = nil;
    foundServices = nil;
    netServiceBrowser = nil;
    [timer invalidate];
    timer = nil;
}

# pragma mark - xbmc play action

- (BOOL)playStream:(NSString*)xbmcName forObject:(id<TVHPlayStreamDelegate>)streamObject withAnalytics:(id<TVHModelAnalyticsProtocol>)analytics {
    
    NSString *xbmcServerAddress = [self.foundServices objectForKey:xbmcName];
    NSString *url = [self validUrlForObject:streamObject];
    if ( xbmcServerAddress && url ) {
        NSURL *jsonRpcXbmcUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/jsonrpc", xbmcServerAddress]];
        
        NSDictionary *httpParams = @{@"jsonrpc": @"2.0",
                                     @"method": @"player.open",
                                     @"params":
                                         @{@"item" :
                                               @{@"file": url}
                                           }
                                     };
        
        NSError *serializationError = nil;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:httpParams options:0 error:&serializationError];
        if (serializationError || !bodyData) { return false; }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:jsonRpcXbmcUrl];
        request.HTTPMethod = @"POST";
        request.HTTPBody = bodyData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        __weak typeof (analytics) weakAnalytics = analytics;
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            typeof (weakAnalytics) strongAnalytics = weakAnalytics;
            if (error) {
                [strongAnalytics sendEventWithCategory:@"playTo"
                                            withAction:@"Xbmc"
                                             withLabel:@"Fail"
                                             withValue:[NSNumber numberWithInt:1]];
            } else {
                [strongAnalytics sendEventWithCategory:@"playTo"
                                            withAction:@"Xbmc"
                                             withLabel:@"Success"
                                             withValue:[NSNumber numberWithInt:1]];
            }
        }];
        [task resume];
        
        return true;
    }
    return false;
}

# pragma mark - xbmc results

- (NSDictionary*)foundServices
{
    return [foundServices copy];
}

- (NSString*)validUrlForObject:(id<TVHPlayStreamDelegate>)streamObject {
    NSString *url;
    
    // once upon a time in xbmc < 15 we could use HTSP.. and then they've removed it from the system
    
    //url = [streamObject htspStreamURL];
    //if ( ! url ) {
        url = [streamObject streamURL];
    //}
    return url;
}

- (NSArray*)availableServers {
    return [foundServices allKeys];
}

- (NSString*)xbmcUrl:(const char*)addressStr onPort:(int)port {
    return [NSString stringWithFormat:@"http://%s:%d", addressStr, port];
}

# pragma mark - resolveIPAddress Methods

- (void)resolveIPAddress:(NSNetService *)service {
    NSNetService *remoteService = service;
    remoteService.delegate = self;
    [remoteService resolveWithTimeout:0];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    for (NSData* data in [service addresses]) {
        char addressBuffer[100];
        struct sockaddr_in* socketAddress = (struct sockaddr_in*) [data bytes];
        int sockFamily = socketAddress->sin_family;
        if (sockFamily == AF_INET ) {//|| sockFamily == AF_INET6 should be considered
            const char* addressStr = inet_ntop(sockFamily,
                                               &(socketAddress->sin_addr), addressBuffer,
                                               sizeof(addressBuffer));
            int port = ntohs(socketAddress->sin_port);
            if (addressStr && port) {
                [foundServices setValue:[self xbmcUrl:addressStr onPort:port] forKey:[service name]];
            }
        }
    }
}

- (void)stopDiscovery{
    [timer invalidate];
    [netServiceBrowser stop];
}

- (void)startDiscover{
    [services removeAllObjects];
    
    searching = NO;
    [netServiceBrowser setDelegate:self];
    [netServiceBrowser searchForServicesOfType:SERVICE_TYPE inDomain:DOMAIN_NAME];
    timer = [NSTimer scheduledTimerWithTimeInterval:DISCOVER_TIMEOUT target:self selector:@selector(stopDiscovery) userInfo:nil repeats:NO];
}

# pragma mark - NSNetServiceBrowserDelegate Methods

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser{
    searching = YES;
    [self updateXbmcServers];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser{
    searching = NO;
    [self updateXbmcServers];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict{
    searching = NO;
    [self handleError:[errorDict objectForKey:NSNetServicesErrorCode]];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)aNetService
               moreComing:(BOOL)moreComing {
    [services addObject:aNetService];
    if ( !moreComing ) {
        //[self stopDiscovery];
        [self updateXbmcServers];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
         didRemoveService:(NSNetService *)aNetService
               moreComing:(BOOL)moreComing{
    [services removeObject:aNetService];
    if ( !moreComing ) {
        [self updateXbmcServers];
    }
}

- (void)handleError:(NSNumber *)error {
    NSLog(@"An error occurred. Error code = %d", [error intValue]);
}

- (void)updateXbmcServers {
    if ( !searching ) {
        for (NSNetService *service in services) {
            [self resolveIPAddress:service];
        }
    }
}

@end

#endif
