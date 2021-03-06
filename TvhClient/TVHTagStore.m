//
//  TVHTagStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/9/13.
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

#import "TVHTagStore.h"
#import "TVHJsonClient.h"
#import "TVHSettings.h"

@interface TVHTagStore()
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, weak) id <TVHTagStoreDelegate> delegate;
@property (nonatomic, strong) NSDate *lastFetchedData;
@end


@implementation TVHTagStore

+ (id)sharedInstance {
    static TVHTagStore *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHTagStore alloc] init];
    });
    
    return __sharedInstance;
}

- (id)init {
    self = [super init];
    if (!self) return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetTagStore)
                                                 name:@"resetAllObjects"
                                               object:nil];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.tags = nil;
    self.lastFetchedData = nil;
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
            [self.delegate didErrorLoadingTagStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *tags = [[NSMutableArray alloc] init];
    
    for (id entry in entries) {
        NSInteger enabled = [[entry objectForKey:@"enabled"] intValue];
        if( enabled ) {
            TVHTag *tag = [[TVHTag alloc] init];
            [tag updateValuesFromDictionary:entry];
            [tags addObject:tag];
        }
    }
     
    NSMutableArray *orderedTags = [[tags sortedArrayUsingSelector:@selector(compareByName:)] mutableCopy];
    
    // All channels
    TVHTag *t = [[TVHTag alloc] initWithAllChannels];
    [orderedTags insertObject:t atIndex:0];
    
    self.tags = [orderedTags copy];
#ifdef TESTING
    NSLog(@"[Loaded Tags]: %d", [self.tags count]);
#endif
}

- (BOOL)isDataOld {
    if ( [self.tags count] == 0 ) {
        return YES;
    }
    if ( !self.lastFetchedData ) {
        return YES;
    }
    TVHSettings *settings = [TVHSettings sharedInstance];
    return ( [[NSDate date] compare:[self.lastFetchedData dateByAddingTimeInterval:[settings cacheTime]]] == NSOrderedDescending );
}

- (void)fetchTagList {
    if( [self isDataOld] ) {
        TVHJsonClient *httpClient = [TVHJsonClient sharedInstance];
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"get", @"op", @"channeltags", @"table", nil];
        
        [httpClient postPath:@"/tablemgr" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self fetchedData:responseObject];
            [self.delegate didLoadTags];
            self.lastFetchedData = [NSDate date];
            
            //NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            //NSLog(@"Request Successful, response '%@'", responseStr);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
                [self.delegate didErrorLoadingTagStore:error];
            }
#ifdef TESTING
            NSLog(@"[TagList HTTPClient Error]: %@", error.description);
#endif
        }];
    } else {
        [self.delegate didLoadTags];
    }
}

- (void)resetTagStore {
    self.tags = nil;
    self.lastFetchedData = nil;
}

- (TVHTagStore *)objectAtIndex:(int) row {
    if ( row < [self.tags count] ) {
        return [self.tags objectAtIndex:row];
    }
    return nil;
}

- (int)count {
    return [self.tags count];
}

- (void)setDelegate:(id <TVHTagStoreDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

@end
