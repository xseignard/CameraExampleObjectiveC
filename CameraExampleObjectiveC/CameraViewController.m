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

#define VIDEO_CAPTURE_WIDTH 1280
#define VIDEO_CAPTURE_HEIGHT 720
//#define VIDEO_CAPTURE_PIXEL_SIZE 4 // 4 bytes for kCVPixelFormatType_32BGRA
#define VIDEO_CAPTURE_PIXEL_SIZE 1 // 1 byte for kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

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
    
    //SET THE CONNECTION PROPERTIES (output properties)
    [self cameraSetOutputProperties];
    
    self.avCaptureAudioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.avCaptureAudioDataOutput setSampleBufferDelegate:self queue:self.dataOutputQueue];
    
    if ([self.session canAddOutput:self.avCaptureAudioDataOutput]) {
        [self.session addOutput:self.avCaptureAudioDataOutput];
    }
    
    
}

- (void) startCapturing {
    //NSLog(@"%@",[UIDevice currentDevice].name);
    //NSLog(@"%s",[[UIDevice currentDevice].name cStringUsingEncoding:NSUTF8StringEncoding]);
    NDIlib_send_create_t options;
    options.p_ndi_name=[[UIDevice currentDevice].name cStringUsingEncoding:NSUTF8StringEncoding];
    options.p_groups = NULL;
    options.clock_video = true;
    options.clock_audio = false;
    
    self.my_ndi_send = NDIlib_send_create(&options);
    if (!self.my_ndi_send) {
        NSLog(@"ERROR: Failed to create sender");
    } else {
        NSLog(@"Successfully created sender");
    }
    
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Assets" ofType:@"bundle"]];
    dispatch_async(dispatch_get_main_queue(), ^{
       UIImage *image  = [UIImage imageNamed:@"stop" inBundle:bundle compatibleWithTraitCollection:nil];
       [self.recordingButton setBackgroundImage:image forState:UIControlStateNormal];
   });
   
   /* Bharat: Add packet receiver*/
   self.avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSArray * formats = [self.avCaptureVideoDataOutput availableVideoCVPixelFormatTypes];
    NSLog(@"availableVideoCVPixelFormatTypes: %@",formats);
//    for (int i=0;  i< [formats count];  i++) {
//        NSNumber * aFormat = [formats objectAtIndex:i];
//        NSString *hex = [NSString stringWithFormat:@"%2lX", (unsigned long)[aFormat integerValue]];
//    }
   [self.avCaptureVideoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
   NSMutableDictionary * videoSettings = [[NSMutableDictionary alloc] init];
   //[videoSettings setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
   [videoSettings setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
   [videoSettings setObject:[NSNumber numberWithInt:VIDEO_CAPTURE_WIDTH] forKey:(id)kCVPixelBufferWidthKey];
   [videoSettings setObject:[NSNumber numberWithInt:VIDEO_CAPTURE_HEIGHT] forKey:(id)kCVPixelBufferHeightKey];
   self.avCaptureVideoDataOutput.videoSettings = videoSettings;
   [self.avCaptureVideoDataOutput setSampleBufferDelegate:self queue:self.dataOutputQueue];
   
   if ([self.session canAddOutput:self.avCaptureVideoDataOutput]) {
       [self.session addOutput:self.avCaptureVideoDataOutput];
   }
}

-(void) stopCapturing {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Assets" ofType:@"bundle"]];
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

//********** START STOP RECORDING BUTTON **********
- (IBAction)StartStopButtonPressed:(id)sender {
    
    if (!self.isRecording) {
        //----- START RECORDING -----
        NSLog(@"START RECORDING");
        self.isRecording = YES;
        [self startCapturing];
    } else {
        //----- STOP RECORDING -----
        NSLog(@"STOP RECORDING");
        self.isRecording = NO;
         [self stopCapturing];
    }
}

- (IBAction)goBack:(id)sender {
    if (self.isRecording) {
        [self stopCapturing];
    }
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
        //NSLog(@"didOutputSampleBuffer");
        if (output == self.avCaptureVideoDataOutput) {
            //NSLog(@"Video packet");
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            
            NDIlib_video_frame_v2_t video_frame;
            video_frame.xres = VIDEO_CAPTURE_WIDTH;
            video_frame.yres = VIDEO_CAPTURE_HEIGHT;
            //video_frame.FourCC = NDIlib_FourCC_type_BGRA; // kCVPixelFormatType_32BGRA
            video_frame.FourCC = NDIlib_FourCC_type_UYVY; // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
//            video_frame.timecode = NDIlib_send_timecode_synthesize;
            video_frame.line_stride_in_bytes = VIDEO_CAPTURE_WIDTH * VIDEO_CAPTURE_PIXEL_SIZE;
            video_frame.p_data = CVPixelBufferGetBaseAddress(pixelBuffer);
            NDIlib_send_send_video_v2(self.my_ndi_send, &video_frame);
        } else if (output == self.avCaptureAudioDataOutput) {
            NSLog(@"Audio packet");
//            CMTime audioSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//            
//            CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
//            size_t lengthAtOffset;
//            size_t totalLength;
//            char *data;
//            CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, &data);
//
//            
//            NDIlib_audio_frame_v2_t audio_frame_data;
//            //audio_frame_data.timestamp =
//            audio_frame_data.sample_rate = [AVAudioSession sharedInstance].sampleRate;
//            audio_frame_data.no_channels =(int) [AVAudioSession sharedInstance].outputNumberOfChannels;
//            audio_frame_data.p_data =data;

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
