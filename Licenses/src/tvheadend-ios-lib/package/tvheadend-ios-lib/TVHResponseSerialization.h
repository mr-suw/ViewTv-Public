//
//  TVHResponseSerialization.h
//  tvheadend-ios-lib
//
//  Internal serialization protocol replacing AFURLResponseSerialization.
//  Used by TVHJsonClient's compound response parsing chain.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Drop-in replacement for AFURLResponseSerialization scoped to tvheadend-ios-lib.
 Each serializer in the compound chain attempts to parse the raw response data.
 The first serializer that succeeds without an error wins.
 */
@protocol TVHResponseSerialization <NSObject>

/**
 Attempts to deserialize the given response data into an object.

 @param response  The URL response (may be nil in test scenarios).
 @param data      Raw response bytes from the server.
 @param error     On failure, populated with the parse error.
 @return          A parsed object (e.g. NSDictionary / NSArray), or nil on failure.
 */
- (nullable id)responseObjectForResponse:(nullable NSURLResponse *)response
                                    data:(nullable NSData *)data
                                   error:(NSError * _Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
