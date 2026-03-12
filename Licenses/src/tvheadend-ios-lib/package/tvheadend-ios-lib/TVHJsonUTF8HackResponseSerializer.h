//
//  TVHJsonUTF8HackResponseSerializer.h
//  tvheadend-ios-lib
//
//  Created by Luis Fernandes on 21/08/2017.
//  Copyright © 2017 zipleen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TVHResponseSerialization.h"

/**
 Last-resort serializer: replaces non-printable / high-byte characters with spaces
 before attempting standard NSJSONSerialization parsing.
 */
@interface TVHJsonUTF8HackResponseSerializer : NSObject <TVHResponseSerialization>

+ (instancetype)serializer;

@end
