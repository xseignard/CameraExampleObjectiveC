//
//  FeedDetailsViewController.m
//  CameraExampleObjectiveC
//
//  Created by Apple on 06/05/20.
//  Copyright © 2020 Mobiona. All rights reserved.
//

#import "FeedDetailsViewController.h"

@interface FeedDetailsViewController ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet GLKView *feedView;
@property (nonatomic) NDIlib_recv_instance_t my_ndi_recv;
@property (nonatomic) BOOL shouldRecv;
@property (nonatomic) CGSize currentSize;
@property (nonatomic) CVPixelBufferPoolRef cvpool;
@property (nonatomic) EAGLContext * eaglContext;
@property (nonatomic) CIContext * ciContext;
@property (nonatomic) BOOL aspectFit;


@end

@implementation FeedDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.aspectFit = false;   // otherwise aspect fill
    NSMutableDictionary * contextOptions = [[NSMutableDictionary alloc] initWithCapacity:1];
    [contextOptions setObject:[[NSNull alloc]init] forKey:kCIContextWorkingColorSpace];
    self.eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self.ciContext = [CIContext contextWithEAGLContext:self.eaglContext options:contextOptions];
    
    self.my_ndi_recv = nil;
    self.shouldRecv = NO;
    // Do any additional setup after loading the view.
    
    self.feedView.context = self.eaglContext;
    // definitely don't need retina scale for something going to the board
    self.feedView.contentScaleFactor = 1;
    
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.shouldRecv = YES;
    [self startReceiving];
}

- (void)viewWillDisappear:(BOOL)animated {
    self.shouldRecv = NO;
    [super viewWillDisappear:animated];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void) startReceiving {
    if (self.activityIndicator.animating == YES) {
        return;
    }
    
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        [self startReceivingApiCall];
    });
}

-(void) startReceivingApiCall {
    if (self.my_ndi_recv) {
        NDIlib_recv_destroy(self.my_ndi_recv);
        self.my_ndi_recv = nil;
    }
    self.my_ndi_recv = NDIlib_recv_create_v2(nil);
    if (!self.my_ndi_recv) {
        NSLog(@"ERROR: Failed to create receiver");
        return;
    } else {
        NSLog(@"Successfully created receiver");
    }
    NDIlib_source_t aSource = self.ndi_source;
    NDIlib_recv_connect(self.my_ndi_recv, &aSource);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator stopAnimating];
    });
    
    while( self.shouldRecv == YES ) {
        NDIlib_video_frame_v2_t video_recv;
        NDIlib_audio_frame_v2_t audio_recv;
        NDIlib_frame_type_e aType = NDIlib_recv_capture_v2(self.my_ndi_recv, &video_recv, &audio_recv, nil, 1500);
        //NSLog(@"Received type=%d",aType);
        switch(aType) {
            case NDIlib_frame_type_none:
                // TODO
                break;
            case NDIlib_frame_type_video:
                [self processVideo:&video_recv];
                NDIlib_recv_free_video_v2(self.my_ndi_recv, &video_recv);
                break;
            case NDIlib_frame_type_audio:
                [self processAudio:&audio_recv];
                NDIlib_recv_free_audio_v2(self.my_ndi_recv, &audio_recv);
                break;
            case NDIlib_frame_type_metadata:
                // TODO
                break;
            case NDIlib_frame_type_error:
                // TODO
                break;
            case NDIlib_frame_type_status_change:
                // TODO
                break;
            case NDIlib_frame_type_max:
                // TODO
                break;
        } // switch
    } // while
    
    if (self.my_ndi_recv) {
        NDIlib_recv_destroy(self.my_ndi_recv);
        self.my_ndi_recv = nil;
    }
    
}

-(void) processVideo:(NDIlib_video_frame_v2_t *) ndi_frame {
    if (!ndi_frame) { return; }
    
    CGSize frameSize = CGSizeMake(ndi_frame->xres, ndi_frame->yres);
    OSType pixelFormat;
    switch(ndi_frame->FourCC)
    {
        case NDIlib_FourCC_type_BGRA:
        case NDIlib_FourCC_type_BGRX:
            pixelFormat = kCVPixelFormatType_32BGRA;
            break;
        case NDIlib_FourCC_type_RGBA:
        case NDIlib_FourCC_type_RGBX:
            pixelFormat = kCVPixelFormatType_32RGBA;
            break;
        case NDIlib_FourCC_type_UYVA:
        case NDIlib_FourCC_type_UYVY:
        default:
            pixelFormat = kCVPixelFormatType_422YpCbCr8;
            break;
    }
    if (!CGSizeEqualToSize(_currentSize, frameSize))
    {
        _currentSize = frameSize;
        [self createPixelBufferPoolForSize:frameSize withFormat:pixelFormat];
    }
    
    
    CVPixelBufferRef buf;
    CVPixelBufferPoolCreatePixelBuffer(NULL, _cvpool, &buf);
    
    CVPixelBufferLockBaseAddress(buf, 0);
    
    uint8_t *dst_addr = CVPixelBufferGetBaseAddress(buf);
    memcpy(dst_addr, ndi_frame->p_data, ndi_frame->yres*ndi_frame->line_stride_in_bytes);
    
    CVPixelBufferUnlockBaseAddress(buf, 0);
    
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:buf];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self drawVideoFrame:sourceImage];
    });
}
-(void) processAudio:(NDIlib_audio_frame_v2_t *) ndi_frame {
    if (!ndi_frame) { return; }
    
}

-(BOOL) createPixelBufferPoolForSize:(CGSize) size withFormat:(OSType)format
{
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setValue:[NSNumber numberWithInt:size.width] forKey:(NSString *)kCVPixelBufferWidthKey];
    [attributes setValue:[NSNumber numberWithInt:size.height] forKey:(NSString *)kCVPixelBufferHeightKey];
    [attributes setValue:@{} forKey:(NSString *)kCVPixelBufferIOSurfacePropertiesKey];
    [attributes setValue:[NSNumber numberWithUnsignedInt:format] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    
    if (_cvpool)
    {
        CVPixelBufferPoolRelease(_cvpool);
    }
    
    CVReturn result = CVPixelBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)(attributes), &_cvpool);
    
    if (result != kCVReturnSuccess)
    {
        return NO;
    }
    
    return YES;
    
}

-(void) drawVideoFrame:(CIImage *) sourceImage {
    CGRect sourceExtent = sourceImage.extent;
    CGFloat sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
    CGFloat previewAspect = self.feedView.bounds.size.width  / self.feedView.bounds.size.height;
    
    CGRect sourceBounds = sourceExtent;
    CGRect destBounds = self.feedView.bounds;

    if (self.aspectFit) {
        if (sourceAspect > previewAspect) {
            destBounds.size.height = destBounds.size.width / sourceAspect;
            destBounds.origin.y = (self.feedView.bounds.size.height - destBounds.size.height) / 2;
        } else {
            destBounds.size.width = destBounds.size.height * sourceAspect;
            destBounds.origin.x = (self.feedView.bounds.size.width - destBounds.size.width) / 2;
        }
    } else {
        if (sourceAspect > previewAspect) {
            sourceBounds.origin.x += (sourceBounds.size.width - sourceBounds.size.height * previewAspect) / 2;
            sourceBounds.size.width = sourceBounds.size.height * previewAspect;
        } else {
            sourceBounds.origin.y += (sourceBounds.size.height - sourceBounds.size.width / previewAspect) / 2;
            sourceBounds.size.height = sourceBounds.size.width / previewAspect;
        }
    }
    
    [self.feedView bindDrawable];
    
    if (self.eaglContext != [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:self.eaglContext];
    }
    
    // clear eagl view to grey
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    //glClear(GLbitfield(GL_COLOR_BUFFER_BIT));
    
    // set the blend mode to "source over" so that CI will use that
    //glEnable(GLenum(GL_BLEND));
    glEnable(GL_BLEND);
    //glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA));
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    [self.ciContext drawImage:sourceImage inRect:destBounds fromRect:sourceBounds];
    [self.feedView display];
}

@end
