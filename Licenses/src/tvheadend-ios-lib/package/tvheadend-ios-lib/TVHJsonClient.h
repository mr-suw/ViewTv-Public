//
//  TVHJsonClient.h
//  TVHeadend iPhone Client
//
//  Created by Luis Fernandes on 2/22/13.
//  Copyright 2013 Luis Fernandes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import <Foundation/Foundation.h>

@class TVHServerSettings;

/**
 TVHJsonClient wraps NSURLSession for all tvheadend API communication.

 It is a drop-in replacement for the previous AFHTTPSessionManager-based
 implementation. The public interface (getPath:parameters:success:failure: /
 postPath:parameters:success:failure:) is identical so all existing
 TVHApiClient / store callers require zero changes.

 Response parsing uses an internal compound chain:
   1. Standard NSJSONSerialization
   2. TVHJsonUTF8AutoCharsetResponseSerializer  (encoding heuristics)
   3. TVHJsonUTF8HackResponseSerializer         (last-resort character sanitise)
 */
@interface TVHJsonClient : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate>

/// YES once the client is ready to dispatch requests (SSH port-forward settled, or immediately for plain TCP).
@property (nonatomic) BOOL readyToUse;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSettings:(TVHServerSettings *)settings NS_DESIGNATED_INITIALIZER;

- (NSURLSessionDataTask *)getPath:(NSString *)path
                       parameters:(NSDictionary *)parameters
                          success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                          failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                           success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                           failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

@end
