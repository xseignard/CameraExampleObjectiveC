//
//  FeedDetailsViewController.h
//  CameraExampleObjectiveC
//
//  Created by Apple on 06/05/20.
//  Copyright © 2020 Mobiona. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreImage/CoreImage.h>
#include "Processing.NDI.Lib.h"

NS_ASSUME_NONNULL_BEGIN

@interface FeedDetailsViewController : UIViewController
@property (nonatomic) NDIlib_source_t ndi_source;
@end

NS_ASSUME_NONNULL_END
