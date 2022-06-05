//
//  CameraController.m
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#import "CameraController.h"
#import "OpenCVManager.h"

@interface CameraController () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_queue_t movieWritingQueue;
    CMBufferQueueRef previewBufferQueue;
    CVImageBufferRef cameraFrame;
}

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *videoDevice;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;

@end

@implementation CameraController

- (instancetype)initCamera
{
    self = [super init];
    
    if (self)
    {
        NSError *error;
        
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
        
        self.videoDevice = [CameraController frontCaptureDevice];
        
        //Turn off autofocus
        [self.videoDevice lockForConfiguration:nil];
        
        //self.videoDevice.focusMode = AVCaptureFocusModeAutoFocus;
        
        AVCaptureDeviceFormat *format = [self getVideoFormat];
        
        if(format != nil) //We are on an old iPhone or some kind of iPad that doesnt support 60FPS at the resolution we want
        {
            self.defaultFormat = format;
            [self.videoDevice setActiveFormat:format];
        }
        
        [self.videoDevice unlockForConfiguration];
        
        NSLog(@"videoDevice.activeFormat:%@", self.videoDevice.activeFormat);
        
        AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&error];
        
        if (error) {
            NSLog(@"Video input creation failed");
            return nil;
        }
        
        if (![self.captureSession canAddInput:videoIn]) {
            NSLog(@"Video input add-to-session failed");
            return nil;
        }
        [self.captureSession addInput:videoIn];
        
        // Video
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.captureSession addOutput:videoDataOutput];
        
        [videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        
        movieWritingQueue = dispatch_queue_create("com.rollyk.moviewriting", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t videoCaptureQueue = dispatch_queue_create("com.rollyk.videocapture", NULL);
        [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
        [videoDataOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
        
        self.videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        //videoOrientation = [self.videoConnection videoOrientation];
        
        // BufferQueue
        /*
        OSStatus err = CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &previewBufferQueue);
        NSLog(@"CMBufferQueueCreate error:%d", err);
        */
        
        [self startCaptureSession];
    }
    
    return self;
}

- (void)stopCaptureSession
{
    [self.captureSession stopRunning];
}

- (void)startCaptureSession
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didStartSession) name:AVCaptureSessionDidStartRunningNotification object:nil];
    
    [self.captureSession startRunning];
    
    [self.videoDevice lockForConfiguration:nil];
    float desiredFPS = 30.0;
    [self.videoDevice setActiveVideoMaxFrameDuration:CMTimeMake( 1, desiredFPS )];
    [self.videoDevice setActiveVideoMinFrameDuration:CMTimeMake( 1, desiredFPS )];
    [self.videoDevice unlockForConfiguration];
}

- (void)didStartSession
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if ([self.delegate respondsToSelector:@selector(onCaptureSessionStarted)])
        {
            [self.delegate onCaptureSessionStarted];
        }
    });
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:nil];
}

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        
        if ([self.assetWriter startWriting]) {
            
            CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.assetWriter startSessionAtSourceTime:timestamp];
        }
        else {
            
            NSLog(@"AVAssetWriter startWriting error:%@", self.assetWriter.error);
        }
    }
    
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        
        if (mediaType == AVMediaTypeVideo) {
            
            if (self.assetWriterVideoInput.readyForMoreMediaData) {
                
                if (![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"AVAssetWriterInput video appendSapleBuffer error:%@", self.assetWriter.error);
                    
                    return;
                }
            }
        }
    }
}

// =============================================================================
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"DROPPED BUFFER SAMPLE  %d   %d", self.videoDevice.activeVideoMinFrameDuration.timescale,self.videoDevice.activeVideoMaxFrameDuration.timescale);
}

- (void)    captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
    CFRetain(sampleBuffer);
    
    cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    int bufferHeight = CVPixelBufferGetHeight(cameraFrame);
    int bufferWidth = CVPixelBufferGetWidth(cameraFrame);
    
    CIImage *cImage = [CIImage imageWithCVImageBuffer:cameraFrame];
    CMTime t = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CGRect r = CGRectMake(0, 0, bufferWidth, bufferHeight);
    
    CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    
    CFRelease(sampleBuffer);
    
    [[OpenCVManager sharedInstance] addCVimage:cImage withFrame:r andTime:t];
}

+ (AVCaptureDevice *)frontCaptureDevice
{
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    
    NSArray *videoDevices = [captureDeviceDiscoverySession devices];
    //NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionFront)
        {
            return device;
        }
    }
    
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

- (AVCaptureDeviceFormat *)getVideoFormat
{
    float desiredFPS = 30.0; //Hard coded gross for now
    AVCaptureDeviceFormat *selectedFormat = nil;
    int32_t maxWidth = 640;
    int32_t maxHeight = 480;
    AVFrameRateRange *frameRateRange = nil;
    
    for (AVCaptureDeviceFormat *format in [self.videoDevice formats])
    {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges)
        {
            CMFormatDescriptionRef desc = format.formatDescription;
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(desc);
            int32_t width = dimensions.width;
            int32_t height = dimensions.height;

            if (range.minFrameRate <= desiredFPS && desiredFPS <= range.maxFrameRate && width == maxWidth && height == maxHeight)
            {
                if(range.maxFrameRate >= desiredFPS)
                {
                    //NSLog(@"THEEEE FORMAT:  %i  %i  %f", width, height, range.maxFrameRate);
                    selectedFormat = format;
                    frameRateRange = range;
                    maxWidth = width;
                }
            }
        }
    }
    
    if(selectedFormat)
        return selectedFormat;
    else
        return nil;
}
    
@end
