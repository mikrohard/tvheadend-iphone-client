//
//  TVHRecordingsViewController.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/27/13.
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

#import "TVHRecordingsViewController.h"
#import "CKRefreshControl.h"
#import "TVHShowNotice.h"
#import "TVHShowNotice.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <QuartzCore/QuartzCore.h>
#import "TVHRecordingsDetailViewController.h"
#import "NSString+FileSize.h"

#define SEGMENT_UPCOMING_REC 0
#define SEGMENT_COMPLETED_REC 1
#define SEGMENT_FAILED_REC 2
#define SEGMENT_AUTOREC 3

@interface TVHRecordingsViewController ()
@property (strong, nonatomic) TVHDvrStore *dvrStore;
@property (strong, nonatomic) TVHAutoRecStore *autoRecStore;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@end

@implementation TVHRecordingsViewController {
    NSDateFormatter *dateFormatter;
}

- (TVHDvrStore*)dvrStore {
    if ( _dvrStore == nil) {
        _dvrStore = [TVHDvrStore sharedInstance];
    }
    return _dvrStore;
}

- (TVHAutoRecStore*)autoRecStore {
    if ( _autoRecStore == nil) {
        _autoRecStore = [TVHAutoRecStore sharedInstance];
    }
    return _autoRecStore;
}

- (void)receiveDvrNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"didSuccessDvrAction"] ) {
        if ( [notification.object isEqualToString:@"deleteEntry"]) {
            [TVHShowNotice successNoticeInView:self.view title:NSLocalizedString(@"Succesfully Deleted Recording", nil)];
        }
        else if([notification.object isEqualToString:@"cancelEntry"]) {
            [TVHShowNotice successNoticeInView:self.view title:NSLocalizedString(@"Succesfully Canceled Recording", nil)];
        }
    }
}

- (void)resetRecordingsStore {
    [self.dvrStore fetchDvr];
    [self.autoRecStore fetchDvrAutoRec];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView setDelegate:self];
    [self.tableView setDataSource:self];
    
    [self.dvrStore setDelegate:self];
    [self.dvrStore fetchDvr];
    
    [self.autoRecStore setDelegate:self];
    [self.autoRecStore fetchDvrAutoRec];
    
    //pull to refresh
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(pullToRefreshViewShouldRefresh) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveDvrNotification:)
                                                 name:@"didSuccessDvrAction"
                                               object:nil];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"E d MMM, HH:mm"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetRecordingsStore)
                                                 name:@"resetAllObjects"
                                               object:nil];
    
    //self.segmentedControl.arrowHeightFactor *= -1.0;
}

- (void)viewDidUnload {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setSegmentedControl:nil];
    [self setTableView:nil];
    [self setDvrStore:nil];
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if ( self.segmentedControl.selectedSegmentIndex == SEGMENT_AUTOREC ) {
        if ( [self.autoRecStore count] == 0 ) {
            return NSLocalizedString(@"No recordings found.", nil);
        }
    } else {
        if ( [self.dvrStore count:self.segmentedControl.selectedSegmentIndex] == 0 ) {
            return NSLocalizedString(@"No recordings found.", nil);
        }
    }
    return nil;
}

- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    //create the uiview container
    UIView *tfooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, 45)];
    tfooterView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    //create the uilabel for the text
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(_tableView.frame.size.width/2-120, 0, 240, 35)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:17];
    label.numberOfLines = 2;
    label.lineBreakMode = UILineBreakModeWordWrap;
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor colorWithRed:0.298039 green:0.337255 blue:0.423529 alpha:1];
    label.shadowColor = [UIColor whiteColor];
    label.text = [self tableView:self.tableView titleForFooterInSection:section];
    label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
    //add the label to the view
    [tfooterView addSubview:label];
    
    return tfooterView;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if( self.segmentedControl.selectedSegmentIndex == SEGMENT_AUTOREC ) {
        return [self.autoRecStore count];
    } else {
        return [self.dvrStore count:self.segmentedControl.selectedSegmentIndex];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"RecordStoreTableItems";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier ];
    
    if(cell==nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    UILabel *titleLabel = (UILabel *)[cell viewWithTag:100];
	UILabel *dateLabel = (UILabel *)[cell viewWithTag:101];
    UILabel *statusLabel = (UILabel *)[cell viewWithTag:102];
    UIImageView *channelImage = (UIImageView *)[cell viewWithTag:103];
    
    if ( self.segmentedControl.selectedSegmentIndex == SEGMENT_AUTOREC ) {
        TVHAutoRecItem *autoRecItem = [self.autoRecStore objectAtIndex:indexPath.row];
        titleLabel.text = autoRecItem.title;
        dateLabel.text = autoRecItem.channel;
        statusLabel.text = [NSString stringOfWeekdaysLocalizedFromArray:[autoRecItem.weekdays componentsSeparatedByString:@","] joinedByString:@","];
        [channelImage setImage:[UIImage imageNamed:@"tv2.png"]];

    } else {
        TVHDvrItem *dvrItem = [self.dvrStore objectAtIndex:indexPath.row forType:self.segmentedControl.selectedSegmentIndex];
        titleLabel.text = dvrItem.fullTitle;
        dateLabel.text = [NSString stringWithFormat:@"%@ (%d min)", [dateFormatter stringFromDate:dvrItem.start], dvrItem.duration/60 ];
        statusLabel.text = dvrItem.status;
        [channelImage setImageWithURL:[NSURL URLWithString:dvrItem.chicon] placeholderImage:[UIImage imageNamed:@"tv2.png"]];
    }
        
    // rouding corners - this makes the animation in ipad become VERY SLOW!!!
    //channelImage.layer.cornerRadius = 5.0f;
    channelImage.layer.masksToBounds = NO;
    channelImage.layer.borderColor = [UIColor lightGrayColor].CGColor;
    channelImage.layer.borderWidth = 0.4;
    channelImage.layer.shouldRasterize = YES;
    
    UIImageView *separator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"separator.png"]];
    [cell.contentView addSubview: separator];
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        if ( self.segmentedControl.selectedSegmentIndex == SEGMENT_AUTOREC ) {
            TVHAutoRecItem *autoRecItem = [self.autoRecStore objectAtIndex:indexPath.row];
            [autoRecItem deleteAutoRec];
        } else {
            TVHDvrItem *dvrItem = [self.dvrStore objectAtIndex:indexPath.row forType:self.segmentedControl.selectedSegmentIndex];
            [dvrItem deleteRecording];
        }

        // because our recordings aren't really deleted right away, we won't have cute animations because we want confirmation that the recording was in fact removed
        //[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }   
     
}

- (float)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.01f;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if( self.segmentedControl.selectedSegmentIndex == SEGMENT_AUTOREC ) {
        [self performSegueWithIdentifier:@"DvrAutoRecDetailSegue" sender:self];
    } else {
        [self performSegueWithIdentifier:@"DvrDetailSegue" sender:self];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"DvrDetailSegue"]) {
        
        NSIndexPath *path = [self.tableView indexPathForSelectedRow];
        TVHDvrItem *item = [self.dvrStore objectAtIndex:path.row forType:self.segmentedControl.selectedSegmentIndex];
        
        TVHRecordingsDetailViewController *vc = segue.destinationViewController;
        [vc setDvrItem:item];
    }
}

- (IBAction)segmentedDidChange:(id)sender {
    [self.tableView reloadData];
}

- (void)pullToRefreshViewShouldRefresh
{
    [self.autoRecStore fetchDvrAutoRec];
    [self.dvrStore fetchDvr];
}

- (void)didLoadDvr {
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (void)didLoadDvrAutoRec {
    [self didLoadDvr];
}

- (void)didErrorDvrStore:(NSError *)error {
    [TVHShowNotice errorNoticeInView:self.view title:NSLocalizedString(@"Network Error", nil) message:error.localizedDescription];
    
    [self.refreshControl endRefreshing];
}

- (void)didErrorDvrAutoStore:(NSError *)error {
    [self didErrorDvrStore:error];
}

@end
