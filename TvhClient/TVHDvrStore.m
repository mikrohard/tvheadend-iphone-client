//
//  TVHDvrStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 28/02/13.
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

#import "TVHDvrStore.h"
#import "TVHJsonClient.h"

@interface TVHDvrStore()
@property (nonatomic, strong) NSArray *dvrItems;
@property (nonatomic, weak) id <TVHDvrStoreDelegate> delegate;
@property (nonatomic, strong) NSArray *cachedDvrItems; // the table delegate will get only the items in this array
@property (nonatomic) NSInteger cachedType;
@end

@implementation TVHDvrStore

+ (id)sharedInstance {
    static TVHDvrStore *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHDvrStore alloc] init];
    });
    
    return __sharedInstance;
}

- (id)init {
    self = [super init];
    self.cachedType = -1;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveDvrdbNotification:)
                                                 name:@"dvrdbNotificationClassReceived"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetDvrStore)
                                                 name:@"resetAllObjects"
                                               object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.dvrItems = nil;
    self.cachedDvrItems = nil;
}

- (void)receiveDvrdbNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"dvrdbNotificationClassReceived"]) {
        NSDictionary *message = (NSDictionary*)[notification object];
        if ( [[message objectForKey:@"reload"] intValue] == 1 ) {
            [self fetchDvr];
        }
    }
}

- (void)resetDvrStore {
    self.dvrItems = nil;
    self.cachedDvrItems = nil;
}

- (NSArray*)dvrItems {
    if ( !_dvrItems ) {
        _dvrItems = [[NSArray alloc] init];
    }
    return _dvrItems;
}

- (void)addDvrItemToStore:(TVHDvrItem*)dvritem {
    // don't add duplicate items - need to search in the array!
    if ( [self.dvrItems indexOfObject:dvritem] == NSNotFound ) {
        self.dvrItems = [self.dvrItems arrayByAddingObject:dvritem];
    }
}

- (void)fetchedData:(NSData *)responseData withType:(NSInteger)type {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorDvrStore:)]) {
            [self.delegate didErrorDvrStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    //NSMutableArray *dvrItems = [[NSMutableArray alloc] init];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHDvrItem *dvritem = [[TVHDvrItem alloc] init];
        [dvritem updateValuesFromDictionary:obj];
        dvritem.dvrType = type;
        
        [self addDvrItemToStore:dvritem];
    }];
    
    /*if ( [self.dvrItems count] > 0) {
        self.dvrItems = [self.dvrItems arrayByAddingObjectsFromArray:[dvrItems copy]];
    } else {
        self.dvrItems = [dvrItems copy];
    }*/
    
#ifdef TESTING
    NSLog(@"[Loaded DVR Items, Count]: %d", [self.dvrItems count]);
#endif
}

- (void)fetchDvrItemsFromServer: (NSString*)url withType:(NSInteger)type {
    TVHJsonClient *httpClient = [TVHJsonClient sharedInstance];
    
    [httpClient getPath:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self fetchedData:responseObject withType:type];
        [self.delegate didLoadDvr];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([self.delegate respondsToSelector:@selector(didErrorDvrStore:)]) {
            [self.delegate didErrorDvrStore:error];
        }
#ifdef TESTING
        NSLog(@"[DVR Items HTTPClient Error]: %@", error.localizedDescription);
#endif
    }];
    
}

- (void)fetchDvr {
    self.dvrItems = nil;
    self.cachedDvrItems = nil;
    
    [self fetchDvrItemsFromServer:@"/dvrlist_upcoming" withType:RECORDING_UPCOMING];
    [self fetchDvrItemsFromServer:@"/dvrlist_finished" withType:RECORDING_FINISHED];
    [self fetchDvrItemsFromServer:@"/dvrlist_failed" withType:RECORDING_FAILED];
}

- (NSArray*)dvrItemsForType:(NSInteger)type {
    NSMutableArray *itemsForType = [[NSMutableArray alloc] init];
    
    [self.dvrItems enumerateObjectsUsingBlock:^(TVHDvrItem* obj, NSUInteger idx, BOOL *stop) {
        if ( obj.dvrType == type ) {
            [itemsForType addObject:obj];
        }
    }];
    self.cachedType = -1;
    self.cachedDvrItems = nil;
    return [itemsForType copy];
}

- (void)checkCachedDvrItemsForType:(NSInteger)type {
    if( self.cachedType != type ) {
        self.cachedType = type;
        self.cachedDvrItems = [self dvrItemsForType:type];
    }
}

- (TVHDvrItem *)objectAtIndex:(int)row forType:(NSInteger)type{
    [self checkCachedDvrItemsForType:type];
    
    if ( row < [self.cachedDvrItems count] ) {
        return [self.cachedDvrItems objectAtIndex:row];
    }
    return nil;
}

- (int)count:(NSInteger)type {
    [self checkCachedDvrItemsForType:type];
    
    if ( self.cachedDvrItems ) {
        return [self.cachedDvrItems count];
    }
    return 0;
}

@end
