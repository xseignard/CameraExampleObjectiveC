//
//  CameraViewController.m
//  CameraExampleObjectiveC
//
//  Created by Apple on 23/04/20.
//  Copyright © 2020 Mobiona. All rights reserved.
//

@import AVFoundation;
@import AssetsLibrary;
#import "CameraViewController.h"
#import "AVCamPreviewView.h"
#include "Processing.NDI.Lib.h"

static void*  SessionRunningContext = &SessionRunningContext;
static void*  SystemPressureContext = &SystemPressureContext;

typedef NS_ENUM(NSInteger, AVCamSetupResult) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface CameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic, weak) IBOutlet UIView* previewView;
@property (weak, nonatomic) IBOutlet UIButton *recordingButton;

@property (nonatomic) AVCaptureSession* session;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic) AVCaptureMovieFileOutput* movieFileOutput;
@property (nonatomic) AVCaptureDeviceInput *videoInputDevice;
@property (nonatomic) Boolean isRecording;

@property (nonatomic, retain) AVCaptureVideoDataOutput * avCaptureVideoDataOutput;
@property (nonatomic, retain) AVCaptureAudioDataOutput * avCaptureAudioDataOutput;
@property (nonatomic) dispatch_queue_t dataOutputQueue;
@property (nonatomic) NDIlib_send_instance_t my_ndi_send;

@end

@implementation CameraViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataOutputQueue = dispatch_queue_create("video buffer output", DISPATCH_QUEUE_SERIAL);
    self.my_ndi_send = nil;
    
    // Set up the preview view.
    self.session = [[AVCaptureSession alloc] init];
    
        //ADD VIDEO INPUT
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (videoDevice) {
            NSError *error;
            self.videoInputDevice = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
            if (!error) {
                if ([self.session canAddInput:self.videoInputDevice])
                    [self.session addInput:self.videoInputDevice];
                else
                    NSLog(@"Couldn't add video input");
            }
            else {
                NSLog(@"Couldn't create video input");
            }
        }
        else {
            NSLog(@"Couldn't create video capture device");
        }
        
        //ADD AUDIO INPUT
        NSLog(@"Adding audio input");
        AVCaptureDevice *audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        NSError *error = nil;
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCaptureDevice error:&error];
        if (audioInput)
        {
            [self.session addInput:audioInput];
        }
        
        //----- ADD OUTPUTS -----
        
        //ADD VIDEO PREVIEW LAYER
        NSLog(@"Adding video preview layer");
        [self setPreviewLayer:[[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session]];
        
        self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        

        
        
        //----- SET THE IMAGE QUALITY / RESOLUTION -----
        //Options:
        //    AVCaptureSessionPresetHigh - Highest recording quality (varies per device)
        //    AVCaptureSessionPresetMedium - Suitable for WiFi sharing (actual values may change)
        //    AVCaptureSessionPresetLow - Suitable for 3G sharing (actual values may change)
        //    AVCaptureSessionPreset640x480 - 640x480 VGA (check its supported before setting it)
        //    AVCaptureSessionPreset1280x720 - 1280x720 720p HD (check its supported before setting it)
        //    AVCaptureSessionPresetPhoto - Full photo resolution (not supported for video output)
        NSLog(@"Setting image quality");
        [self.session setSessionPreset:AVCaptureSessionPresetMedium];
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
                [self.session setSessionPreset:AVCaptureSessionPreset1280x720];
        }
        
        //----- DISPLAY THE PREVIEW LAYER -----
        //Display it full screen under out view controller existing controls
        NSLog(@"Display the preview layer");
        CGRect layerRect = self.view.frame;
        self.previewLayer.frame = layerRect;
        // [self.previewLayer setBounds:layerRect];
        [self.previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect), CGRectGetMidY(layerRect))];
        
        [[self.previewView layer] addSublayer:self.previewLayer];
        
        //----- START THE CAPTURE SESSION RUNNING -----
        [self.session startRunning];
    }

//********** CAMERA SET OUTPUT PROPERTIES **********
- (void) cameraSetOutputProperties
{
    if (self.avCaptureVideoDataOutput == nil) { return; }
    //SET THE CONNECTION PROPERTIES (output properties)
    AVCaptureConnection *captureConnection = [self.avCaptureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //Set landscape (if required)
    if ([captureConnection isVideoOrientationSupported])
    {
        AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
        [captureConnection setVideoOrientation:orientation];
    }
}

//********** START STOP RECORDING BUTTON **********
- (IBAction)StartStopButtonPressed:(id)sender {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Assets" ofType:@"bundle"]];
    if (!self.isRecording) {
        //----- START RECORDING -----
        NSLog(@"START RECORDING");
        self.isRecording = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image  = [UIImage imageNamed:@"stop" inBundle:bundle compatibleWithTraitCollection:nil];
            [self.recordingButton setBackgroundImage:image forState:UIControlStateNormal];
        });
        
        /* Bharat: Add packet receiver*/
        self.avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.avCaptureVideoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
        NSMutableDictionary * videoSettings = [[NSMutableDictionary alloc] init];
        [videoSettings setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        self.avCaptureVideoDataOutput.videoSettings = videoSettings;
        [self.avCaptureVideoDataOutput setSampleBufferDelegate:self queue:self.dataOutputQueue];
        
        if ([self.session canAddOutput:self.avCaptureVideoDataOutput]) {
            [self.session addOutput:self.avCaptureVideoDataOutput];
        }
        
        //SET THE CONNECTION PROPERTIES (output properties)
        [self cameraSetOutputProperties];
        
        self.avCaptureAudioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
        [self.avCaptureAudioDataOutput setSampleBufferDelegate:self queue:self.dataOutputQueue];
        
        if ([self.session canAddOutput:self.avCaptureAudioDataOutput]) {
            [self.session addOutput:self.avCaptureAudioDataOutput];
        }
        
        self.my_ndi_send = NDIlib_send_create(nil);
        if (!self.my_ndi_send) {
            NSLog(@"ERROR: Failed to create sender");
        } else {
            NSLog(@"Successfully created sender");
        }

        
    } else {
        //----- STOP RECORDING -----
        NSLog(@"STOP RECORDING");
        self.isRecording = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image  = [UIImage imageNamed:@"record" inBundle:bundle compatibleWithTraitCollection:nil];
            [self.recordingButton setBackgroundImage:image forState:UIControlStateNormal];
        });
        
        if (self.session != nil) {
            if (self.avCaptureVideoDataOutput != nil) {
                [self.session removeOutput:self.avCaptureVideoDataOutput];
                self.avCaptureVideoDataOutput = nil;
            }
            if (self.avCaptureAudioDataOutput != nil) {
                [self.session removeOutput:self.avCaptureAudioDataOutput];
                self.avCaptureAudioDataOutput = nil;
            }
        } else {
            self.avCaptureVideoDataOutput = nil;
            self.avCaptureAudioDataOutput = nil;
        }
        
        if (self.my_ndi_send) {
            NDIlib_send_destroy(self.my_ndi_send);
            self.my_ndi_send = nil;
        }
    }
}

- (IBAction)goBack:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void) viewDidDisappear:(BOOL)animated {
    [self.session stopRunning];
    [super viewDidDisappear:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.previewLayer.frame = self.view.layer.bounds;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

-(BOOL) shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientation)windowOrientation {
    return self.view.window.windowScene.interfaceOrientation;
}

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsPortrait(deviceOrientation) || UIDeviceOrientationIsLandscape(deviceOrientation)) {
        self.previewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (self.isRecording) {
        NSLog(@"didOutputSampleBuffer");
        if (output == self.avCaptureVideoDataOutput) {
            NSLog(@"Video packet");
            NDIlib_video_frame_v2_t video_frame_data;
            video_frame_data.xres = xres;
            video_frame_data.yres = yres;
            video_frame_data.FourCC = NDIlib_FourCC_type_BGRA;
            video_frame_data.p_data = p_bgra;
            NDIlib_send_send_video(self.my_ndi_send, &video_frame_data);
        } else if (output == self.avCaptureAudioDataOutput) {
            NSLog(@"Audio packet");
        }
    }
}

- (void)captureOutput:(AVCaptureOutput *)output
didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (self.isRecording) {
        return;
    }
    if (output == self.avCaptureVideoDataOutput) {
        NSLog(@"Error: Dropped Video packet");
    } else if (output == self.avCaptureAudioDataOutput) {
        NSLog(@"Error: Dropped Audio packet");
    }
}

@end
