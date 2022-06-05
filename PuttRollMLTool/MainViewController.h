//
//  ViewController.h
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CameraController.h"

@interface MainViewController : UIViewController
{
    BOOL isPreview;
    NSTimer *timer;
    int imageCount;
}

@property (nonatomic, strong) CameraController *cameraController;

@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UILabel *countLabel;
@property (weak, nonatomic) IBOutlet UILabel *connectionLabel;
@property (weak, nonatomic) IBOutlet UIView *connectionIcon;

- (IBAction)onStartStop:(id)sender;
- (IBAction)onCancel:(id)sender;

@end

