//
//  ListTableViewController.h
//  CameraExampleObjectiveC
//
//  Created by Apple on 06/05/20.
//  Copyright © 2020 Mobiona. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ListTableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *listTableView;

@end

NS_ASSUME_NONNULL_END
