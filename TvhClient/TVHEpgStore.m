//
//  TVHEpgStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/10/13.
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

#import "TVHEpgStore.h"
#import "TVHEpg.h"
#import "TVHJsonClient.h"

@interface TVHEpgStore()
@property (nonatomic, strong) NSArray *epgStore;
@property (nonatomic, weak) id <TVHEpgStoreDelegate> delegate;
@property (nonatomic) NSInteger lastEventCount;

@end

@implementation TVHEpgStore

+ (id)sharedInstance {
    static TVHEpgStore *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHEpgStore alloc] init];
    });
    
    return __sharedInstance;
}

- (id)init {
    self = [super init];
    if (!self) return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetEpgStore)
                                                 name:@"resetAllObjects"
                                               object:nil];
    
    return self;
}

- (NSArray*)epgStore {
    if ( !_epgStore ) {
        _epgStore = [[NSArray alloc] init];
    }
    return _epgStore;
}

- (void)resetEpgStore {
    self.epgStore = nil;
    self.filterToChannelName = nil;
    self.filterToProgramTitle = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.epgStore = nil;
}

- (void)addEpgItemToStore:(TVHEpg*)epgItem {
    // don't add duplicate items - need to search in the array!
    if ( [self.epgStore indexOfObject:epgItem] == NSNotFound ) {
        self.epgStore = [self.epgStore arrayByAddingObject:epgItem];
    }
}

- (void)fetchedData:(NSData *)responseData {
    
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingEpgStore:)]) {
            [self.delegate didErrorLoadingEpgStore:error];
        }
        return ;
    }
    
    self.lastEventCount = [[json objectForKey:@"totalCount"] intValue];
    NSArray *entries = [json objectForKey:@"entries"];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHEpg *epg = [[TVHEpg alloc] init];
        [epg updateValuesFromDictionary:obj];
        [self addEpgItemToStore:epg];
    }];
    
#ifdef TESTING
    NSLog(@"[EpgStore: Loaded EPG programs (%@)]: %d", self.filterToChannelName,[self.epgStore count]);
#endif
}

- (NSDictionary*)getPostParametersStartingFrom:(NSInteger)start limit:(NSInteger)limit {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSString stringWithFormat:@"%d", start ],
                                   @"start",
                                   [NSString stringWithFormat:@"%d", limit ],
                                   @"limit",nil];
    
    if( self.filterToChannelName != nil ) {
        [params setObject:self.filterToChannelName forKey:@"channel"];
    }
    
    if( self.filterToProgramTitle != nil ) {
        [params setObject:self.filterToProgramTitle forKey:@"title"];
    }
    
    return [params copy];
}

- (void)retrieveEpgDataFromTVHeadend:(NSInteger)start limit:(NSInteger)limit {
    TVHJsonClient *httpClient = [TVHJsonClient sharedInstance];
    
    NSDictionary *params = [self getPostParametersStartingFrom:start limit:limit];
    
    [httpClient postPath:@"/epg" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self fetchedData:responseObject];
        [self.delegate didLoadEpg:self];
        
        [self getMoreEpg:start limit:limit];
        
        //NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        //NSLog(@"Request Successful, response '%@'", responseStr);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
#ifdef TESTING
        NSLog(@"[EpgStore HTTPClient Error]: %@", error.localizedDescription);
#endif
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingEpgStore:)]) {
            [self.delegate didErrorLoadingEpgStore:error];
        }
    }];
    
}

- (void)getMoreEpg:(NSInteger)start limit:(NSInteger)limit {
    // get last epg
    // check date
    // if date > datenow, get more 50
    
    TVHEpg *last = [self.epgStore lastObject];
    if ( last ) {
        NSDate *localDate = [NSDate date];
#ifdef TESTING
        NSLog(@"localdate: %@ | last start date: %@ %i %i", localDate, last.start);
#endif
        if ( [localDate compare:last.start] == NSOrderedDescending && (start+limit) < self.lastEventCount ) {
            [self retrieveEpgDataFromTVHeadend:(start+limit) limit:50];
        }
    }
}

- (void)downloadEpgList {
    [self retrieveEpgDataFromTVHeadend:[self.epgStore count] limit:50];
}

- (NSArray*)epgStoreItems{
    return self.epgStore;
}

- (void)setDelegate:(id <TVHEpgStoreDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

- (void)setFilterToProgramTitle:(NSString *)filterToProgramTitle {
    _filterToProgramTitle = filterToProgramTitle;
    self.epgStore = nil;
}

- (void)setFilterToChannelName:(NSString *)filterToChannelName {
    _filterToChannelName = filterToChannelName;
    self.epgStore = nil;
}

@end
