//
//  TVHJsonUTF8AutoCharsetResponseSerializer.h
//  tvheadend-ios-lib
//
//  Created by Luis Fernandes on 21/08/2017.
//  Copyright © 2017 zipleen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TVHResponseSerialization.h"

/**
 Second-pass serializer: tries multiple string encodings (UTF-8, Latin-1, ASCII),
 strips control characters, then parses as JSON.
 */
@interface TVHJsonUTF8AutoCharsetResponseSerializer : NSObject <TVHResponseSerialization>

+ (instancetype)serializer;

@end
