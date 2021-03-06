//
//  TVHStatusSubscriptionsViewController.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/18/13.
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

#import "TVHStatusSubscriptionsViewController.h"
#import "CKRefreshControl.h"
#import "TVHShowNotice.h"
#import "TVHCometPollStore.h"
#import "NSString+FileSize.h"

@interface TVHStatusSubscriptionsViewController ()
@property (strong, nonatomic) TVHStatusSubscriptionsStore *statusSubscriptionsStore;
@property (strong, nonatomic) TVHAdaptersStore *adapterStore;
@property (strong, nonatomic) TVHCometPollStore *cometPoll;
@end

@implementation TVHStatusSubscriptionsViewController

- (TVHStatusSubscriptionsStore*) statusSubscriptionsStore {
    if ( _statusSubscriptionsStore == nil) {
        _statusSubscriptionsStore = [TVHStatusSubscriptionsStore sharedInstance];
    }
    return _statusSubscriptionsStore;
}

- (TVHAdaptersStore*) adapterStore {
    if ( _adapterStore == nil) {
        _adapterStore = [TVHAdaptersStore sharedInstance];
    }
    return _adapterStore;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    [self.adapterStore setDelegate:self];
    [self.statusSubscriptionsStore setDelegate:self];
    
    self.cometPoll = [TVHCometPollStore sharedInstance];
    
    //pull to refresh
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(pullToRefreshViewShouldRefresh) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidUnload {
    self.adapterStore = nil;
    self.cometPoll = nil;
    self.statusSubscriptionsStore = nil;
    [self setSwitchPolling:nil];
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.adapterStore fetchAdapters];
    [self.statusSubscriptionsStore fetchStatusSubscriptions];
    [self.switchPolling setOn:[self.cometPoll isTimerStarted] ];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)didLoadStatusSubscriptions {
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (void)didLoadAdapters {
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (void)pullToRefreshViewShouldRefresh
{
    [self.tableView reloadData];
    [self.statusSubscriptionsStore fetchStatusSubscriptions];
    [self.adapterStore fetchAdapters];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ( section == 0 ) {
        return NSLocalizedString(@"Active Subscriptions", nil);
    }
    if ( section == 1 ) {
        return NSLocalizedString(@"Adapters", nil);
    }
    return nil;
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if ( section == 0 ) {
        if ( [self.statusSubscriptionsStore count] == 0 ) {
            return NSLocalizedString(@"No active subscriptions.", nil);
        }
    }
    if ( section == 1 ) {
        if ( [self.adapterStore count] == 0 ) {
            return NSLocalizedString(@"No adapters found.", nil);
        }
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ( section == 0 ) {
        return [self.statusSubscriptionsStore count];
    }
    if ( section == 1 ) {
        return [self.adapterStore count];
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SubscriptionStoreTableItems";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier ];
    
    UILabel *hostnameLabel = (UILabel *)[cell viewWithTag:100];
	UILabel *titleLabel = (UILabel *)[cell viewWithTag:102];
    UILabel *channelLabel = (UILabel *)[cell viewWithTag:103];
    UILabel *serviceLabel = (UILabel *)[cell viewWithTag:104];
    UILabel *startLabel = (UILabel *)[cell viewWithTag:105];
    UILabel *stateLabel = (UILabel *)[cell viewWithTag:106];
    UILabel *errorsLabel = (UILabel *)[cell viewWithTag:107];
	UILabel *bandwidthLabel = (UILabel *)[cell viewWithTag:108];
    
    if ( indexPath.section == 0 ) {
        TVHStatusSubscription *subscription = [self.statusSubscriptionsStore objectAtIndex:indexPath.row];
        
        hostnameLabel.text = subscription.hostname;
        titleLabel.text = subscription.title;
        channelLabel.text = subscription.channel;
        serviceLabel.text = subscription.service;
        startLabel.text = [subscription.start description];
        stateLabel.text = subscription.state;
        errorsLabel.text = [NSString stringWithFormat:@"Errors: %d", subscription.errors];
        bandwidthLabel.text = [NSString stringWithFormat:@"Bw: %@", [NSString stringFromFileSizeInBits:subscription.bw]];
    }
    if ( indexPath.section == 1 ) {
        TVHAdapter *adapter = [self.adapterStore objectAtIndex:indexPath.row];
        
        hostnameLabel.text = adapter.devicename;
        titleLabel.text = adapter.path;
        channelLabel.text = [NSString stringWithFormat:@"Bw %@", [NSString stringFromFileSizeInBits:adapter.bw]];
        serviceLabel.text = adapter.currentMux;
        startLabel.text = [NSString stringWithFormat:@"Snr %.1f dB", adapter.snr];
        stateLabel.text = [NSString stringWithFormat:@"Unc %d", adapter.uncavg];
        errorsLabel.text = [NSString stringWithFormat:@"Ber %d", adapter.ber];
        bandwidthLabel.text = [NSString stringWithFormat:@"Signal %d %%", adapter.signal];
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)didErrorStatusSubscriptionsStore:(NSError *)error {
    [TVHShowNotice errorNoticeInView:self.view title:NSLocalizedString(@"Network Error", nil) message:error.localizedDescription];
    
    [self.refreshControl endRefreshing];
}

- (void)didErrorAdaptersStore:(NSError *)error {
    [TVHShowNotice errorNoticeInView:self.view title:NSLocalizedString(@"Network Error", nil) message:error.localizedDescription];
    
    [self.refreshControl endRefreshing];
}

- (IBAction)switchPolling:(UISwitch*)sender {
    if ( sender.on ) {
        [self.cometPoll startRefreshingCometPoll];
    } else {
        [self.cometPoll stopRefreshingCometPoll];
    }
}

@end
