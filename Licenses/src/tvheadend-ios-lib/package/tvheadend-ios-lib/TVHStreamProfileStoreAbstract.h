//
//  TVHStreamProfileStoreAbstract.h
//  tvheadend-ios-lib
//
//  Created by Luis Fernandes on 25/09/2017.
//  Copyright © 2017 zipleen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TVHStreamProfileStore.h"

@interface TVHStreamProfileStoreAbstract : NSObject <TVHApiClientDelegate, TVHStreamProfileStoreDelegate>
@property (nonatomic, weak) TVHServer *tvhServer;

- (id)initWithTvhServer:(TVHServer*)tvhServer;
- (void)fetchStreamProfiles;
- (NSArray*)profiles;
- (NSArray*)profilesAsString;
@end
