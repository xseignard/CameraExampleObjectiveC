//
//  FeedDetailsViewController.m
//  CameraExampleObjectiveC
//
//  Created by Apple on 06/05/20.
//  Copyright © 2020 Mobiona. All rights reserved.
//

#import "FeedDetailsViewController.h"

@interface FeedDetailsViewController ()
@property (weak, nonatomic) IBOutlet UIView *feedView;

@end

@implementation FeedDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)goBack:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

-(BOOL) shouldAutorotate {
    return YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
