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

static void*  SessionRunningContext = &SessionRunningContext;
static void*  SystemPressureContext = &SystemPressureContext;

typedef NS_ENUM(NSInteger, AVCamSetupResult) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface CameraViewController () <AVCaptureFileOutputRecordingDelegate>
@property (nonatomic, weak) IBOutlet UIView* previewView;
@property (weak, nonatomic) IBOutlet UIButton *recordingButton;

@property (nonatomic) AVCaptureSession* session;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic) AVCaptureMovieFileOutput* movieFileOutput;
@property (nonatomic) AVCaptureDeviceInput *videoInputDevice;
@property (nonatomic) Boolean isRecording;

@end

@implementation CameraViewController
- (void)viewDidLoad {
    [super viewDidLoad];
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
        
        
        //ADD MOVIE FILE OUTPUT
        NSLog(@"Adding movie file output");
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        
        Float64 TotalSeconds = 60;            //Total seconds
        int32_t preferredTimeScale = 30;    //Frames per second
        CMTime maxDuration = CMTimeMakeWithSeconds(TotalSeconds, preferredTimeScale);
        self.movieFileOutput.maxRecordedDuration = maxDuration;
        
        self.movieFileOutput.minFreeDiskSpaceLimit = 1024 * 1024;
        
        if ([self.session canAddOutput:self.movieFileOutput])
            [self.session addOutput:self.movieFileOutput];

        //SET THE CONNECTION PROPERTIES (output properties)
        [self cameraSetOutputProperties];
        
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
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480])
            [self.session setSessionPreset:AVCaptureSessionPreset640x480];
        
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
    //SET THE CONNECTION PROPERTIES (output properties)
    AVCaptureConnection *captureConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
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

        //Create temporary URL to record to
        NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
        NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:outputPath]) {
            NSError *error;
            if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
                //Error - handle if requried
            }
        }
        //Start recording
        [self.movieFileOutput startRecordingToOutputFileURL:outputURL recordingDelegate:self];
    } else {
        //----- STOP RECORDING -----
        NSLog(@"STOP RECORDING");
        self.isRecording = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image  = [UIImage imageNamed:@"record" inBundle:bundle compatibleWithTraitCollection:nil];
            [self.recordingButton setBackgroundImage:image forState:UIControlStateNormal];
        });
        [self.movieFileOutput stopRecording];
    }
}

- (IBAction)goBack:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

//********** DID FINISH RECORDING TO OUTPUT FILE AT URL **********
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    NSLog(@"didFinishRecordingToOutputFileAtURL - enter");
    
    BOOL recordedSuccessfully = YES;
    if ([error code] != noErr) {
        // A problem occurred: Find out if the recording was successful.
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value) {
            recordedSuccessfully = [value boolValue];
        }
    }
    if (recordedSuccessfully) {
        //----- RECORDED SUCESSFULLY -----
        NSLog(@"didFinishRecordingToOutputFileAtURL - success");
    }
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

@end
