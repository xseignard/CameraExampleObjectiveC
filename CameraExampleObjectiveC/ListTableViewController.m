//
//  ListTableViewController.m
//  CameraExampleObjectiveC
//
//  Created by Apple on 06/05/20.
//  Copyright © 2020 Mobiona. All rights reserved.
//

#import "ListTableViewController.h"
#include "Processing.NDI.Lib.h"

@interface ListTableViewController ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) NSArray *activeSources;
@property (nonatomic) NDIlib_find_instance_t ndi_find;

@end

@implementation ListTableViewController
@synthesize listTableView;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.ndi_find = nil;
    self.activeSources = [[NSMutableArray alloc] initWithCapacity:1];
    self.listTableView.delegate = self;
    self.listTableView.dataSource = self;

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self findSources];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.ndi_find) {
        NDIlib_find_destroy(self.ndi_find);
        self.ndi_find = nil;
    }
    [super viewWillDisappear:animated];
}

- (IBAction)goBack:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

-(void) findSources {
    if (self.activityIndicator.animating == YES) {
        return;
    }
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        [self findSourcesApiCall];
    });
}
-(void) findSourcesApiCall {
    if (!self.ndi_find) {
        self.ndi_find = NDIlib_find_create_v2(nil);
    }
    if (!self.ndi_find) {
        NSLog(@"ERROR: Failed to create finder");
    } else {
        NSLog(@"Successfully created finder");
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activityIndicator.hidden = NO;
        [self.activityIndicator startAnimating];
    });
    
    bool source_list_has_changed = NDIlib_find_wait_for_sources(self.ndi_find, 3000/* 3 seconds */);
    
    uint32_t no_srcs; // This will contain how many senders have been found so far.
    const NDIlib_source_t* p_senders = NDIlib_find_get_current_sources(self.ndi_find, &no_srcs);
    
    NSMutableArray * sources = [[NSMutableArray alloc] init];
    for (int i=0; i< no_srcs; i++) {
      NDIlib_source_t aSender = p_senders[i];
      NSMutableDictionary * aSource = [[NSMutableDictionary alloc] init];
      [aSource setObject:[[NSString alloc] initWithUTF8String:aSender.p_ndi_name] forKey:@"p_ndi_name"];
      if (aSender.p_ip_address) {
        [aSource setObject:[[NSString alloc] initWithUTF8String:aSender.p_ip_address] forKey:@"p_ip_address"];
      }
      if (aSender.p_url_address) {
        [aSource setObject:[[NSString alloc] initWithUTF8String:aSender.p_url_address] forKey:@"p_url_address"];
      }
        [sources addObject:aSource];
    }
    
    self.activeSources = sources;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator stopAnimating];
        [self.listTableView reloadData];
    });
    
}

-(BOOL) shouldAutorotate {
    return NO;
}

- (IBAction)refreshButtonClicked:(id)sender {
    [self findSources];
}




#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.activeSources count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"listTableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    // Configure the cell...
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";
    
    if ([self.activeSources count] > [indexPath row]) {
        NSDictionary * aDict = [self.activeSources objectAtIndex:indexPath.row];
        cell.textLabel.text = [aDict objectForKey:@"p_ndi_name"];
        if ([aDict objectForKey:@"p_ip_address"] != nil) {
            cell.detailTextLabel.text = [aDict objectForKey:@"p_ip_address"];
        } else {
            if ([aDict objectForKey:@"p_url_address"] != nil) {
                cell.detailTextLabel.text = [aDict objectForKey:@"p_url_address"];
            }
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSString * storyboardName = @"Main";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
    UIViewController * vc = [storyboard instantiateViewControllerWithIdentifier:@"FeedDetailsViewController"];
    [self presentViewController:vc animated:YES completion:nil];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
