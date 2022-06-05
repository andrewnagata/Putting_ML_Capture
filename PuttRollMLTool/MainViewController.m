//
//  ViewController.m
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#import "MainViewController.h"
#import "BLEManager.h"
#import "OpenCVManager.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onTriggered:)
                                                 name:kTriggered
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onBLEConnect)
                                                 name:kDidConnectPeripheral
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onBLEDisconnect)
                                                 name:kDidDisconnectPeripheral
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNewFrame)
                                                 name:@"CVframe"
                                               object:nil];
    
    [self setBLEStatus:NO];
    
    _cameraController = [[[CameraController alloc] init] initCamera];
    
    [_cancelButton setHidden:YES];
    
    isPreview = YES;
}

- (void)onNewFrame
{
    if(!isPreview)
        return;
    
    UIImage *img = [[OpenCVManager sharedInstance] currentCVbuffer];
    
    [self presentImageToView:img];
}

- (void)onTriggered:(NSNotification *) notification
{
    if(isPreview)
        return;
    
    NSLog(@"Triggerd - grab camera frame");
    
    UIImage *img = [[OpenCVManager sharedInstance] setLastTriggeredImage];
    
    [self presentImageToView:img];
    
    [_cancelButton setHidden:NO];
    
    //Short delay then reset for another
    timer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self captureDelay];
    }];
}

- (void)presentImageToView:(UIImage *)img
{
    UIImage *rotated = [UIImage imageWithCGImage:img.CGImage scale:1.0 orientation:UIImageOrientationRight];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_imageView setImage:rotated];
    });
}

- (void)captureDelay
{
    NSLog(@"All done... RESET");
    
    //Save the curtrent MHI image
    [self saveImageFromCVBuffer:[[OpenCVManager sharedInstance] lastTriggeredImage]];
    
    //Notify the trigger set up we done
    [[BLEManager shared] resetTrigger];
    
    imageCount++;
    [_countLabel setText:[NSString stringWithFormat:@"%i", imageCount]];
    
    [_imageView setImage:nil];
    [_cancelButton setHidden:YES];
}

- (void)saveImageFromCVBuffer:(UIImage *)img
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"hh-mm-ss-SSS"];
    
    NSString *t = [NSString stringWithFormat:@"Ball-%@.jpg", [dateFormatter stringFromDate:[NSDate date]]];
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:t];
    
    NSData *imageData = UIImageJPEGRepresentation(img, 1.0);
    [imageData writeToFile:filePath atomically:YES];
}

- (IBAction)onStartStop:(id)sender
{
    isPreview = !isPreview;
    
    if(!isPreview)
    {
        [_imageView setImage:nil];
        
        [_startStopButton setTitle:@"STOP" forState:UIControlStateNormal];
        
        //Make sure the trigger is active
        [[BLEManager shared] resetTrigger];
        
        imageCount = 0;
        [_countLabel setText:[NSString stringWithFormat:@"%i", imageCount]];
    } else {
        [_startStopButton setTitle:@"START" forState:UIControlStateNormal];
    }
}

- (void)onBLEConnect
{
    [self setBLEStatus:YES];
}

- (void)onBLEDisconnect
{
    [self setBLEStatus:NO];
}

- (void)setBLEStatus:(BOOL)status
{
    if(status)
    {
        [_connectionLabel setText:@"connected"];
        [_connectionIcon setBackgroundColor:[UIColor greenColor]];
    } else {
        [_connectionLabel setText:@"no connection"];
        [_connectionIcon setBackgroundColor:[UIColor orangeColor]];
    }
}

- (IBAction)onCancel:(id)sender
{
    [timer invalidate];
    
    [_imageView setImage:nil];
    
    [_cancelButton setHidden:YES];
    
    [[BLEManager shared] resetTrigger];
}

@end
