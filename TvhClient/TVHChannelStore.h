//
//  TVHChannelStore.h
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/3/13.
//  Copyright 2013 Luis Fernandes
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import "TVHChannel.h"
#import "TVHEpgStore.h"

@protocol TVHChannelStoreDelegate <NSObject>

-(void) didLoadChannels;
-(void) didErrorLoadingChannelStore:(NSError*)error;
@end

@interface TVHChannelStore : NSObject <TVHEpgStoreDelegate>
@property (nonatomic) NSInteger filterTag;
+ (id)sharedInstance;
- (void)fetchChannelList;
- (void)resetChannelStore;

- (TVHChannel *)objectAtIndex:(int) row;
- (int)count;
- (void)setDelegate:(id <TVHChannelStoreDelegate>)delegate;
- (TVHChannel*)channelWithName:(NSString*) name;
- (TVHChannel*)channelWithId:(NSInteger) channelId;
- (NSArray*)getFilteredChannelList;
@end
