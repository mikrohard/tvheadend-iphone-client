//
//  ModelChannelList.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/3/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "ModelChannelList.h"
#import "tvhclientChannelListViewController.h"

@interface ModelChannelList ()
@property (strong, nonatomic) NSArray *channelNames;
@property (weak, nonatomic) tvhclientChannelListViewController *sender;
@end

@implementation ModelChannelList
@synthesize channelNames = _channelNames;

- (NSData*)encodeDictionary:(NSDictionary*)dictionary {
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    for (NSString *key in dictionary) {
        NSString *encodedValue = [[dictionary objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *part = [NSString stringWithFormat: @"%@=%@", encodedKey, encodedValue];
        [parts addObject:part];
    }
    NSString *encodedDictionary = [parts componentsJoinedByString:@"&"];
    return [encodedDictionary dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)fetchedData:(NSData *)responseData {
    //parse out the json data
    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:responseData //1
                                                         options:kNilOptions
                                                           error:&error];
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *channelNames = [[NSMutableArray alloc] init];
    
    NSEnumerator *e = [entries objectEnumerator];
    id channel;
    //for (NSEnumerator *channel in entries) {
    while (channel = [e nextObject]) {
        NSLog(@"json : %@", channel);
        //NSString *ch_icon = [channel objectForKey:@"ch_icon"];
        NSString *name = [channel objectForKey:@"name"];
        //NSString *number = [channel objectForKey:@"number"];
        [channelNames addObject:name];
    }
    self.channelNames = [channelNames copy];
    
}


- (void)startGetTestData {
    
    NSURL *url = [NSURL URLWithString:@"http://192.168.1.250:9981/channels"];
    NSDictionary *postDict = [NSDictionary dictionaryWithObjectsAndKeys:@"list", @"op", nil];
    NSData *postData = [self encodeDictionary:postDict];
    
    // Create the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"%d", postData.length] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    [NSURLConnection
     sendAsynchronousRequest:request
     queue:[NSOperationQueue mainQueue]
     completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
         // do something useful
         if (error) {
             // Deal with your error
             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                 NSLog(@"HTTP Error: %d %@", httpResponse.statusCode, error);
                 return;
             }
             NSLog(@"Error %@", error);
             return;
         }
         
         //NSString *responeString = [[NSString alloc] initWithData:receivedData
         //                                                encoding:NSUTF8StringEncoding];
         //NSLog(@"received: %@", responeString);
         
         [self fetchedData:data];
         [self.sender reload];
     }];
    
    }

- (NSString *) objectAtIndex:(int) row {
    return [self.channelNames objectAtIndex:row];
}

- (int) count {
    return [self.channelNames count];
}


- (void) setDelegate: (tvhclientChannelListViewController*)sender {
    self.sender = sender;
}
@end
