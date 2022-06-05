//
//  OpenCVManager.h
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 1/1/20.
//  Copyright © 2020 Andrew Nagata. All rights reserved.
//

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
#endif

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//#import <CoreML/CoreML.h>
//#import <Vision/Vision.h>
#import <AVFoundation/AVFoundation.h>
#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OpenCVManagerDelegate <NSObject>

- (void)didDetectBallRolling;

@end

@interface OpenCVManager : NSObject
{
    CIImage *currentlyAnalyzedImage;

    dispatch_queue_t imageProcessQueue;
    
    UIImage *currentImage;
    UIImage *lastTriggeredImage;
}

+ (id)sharedInstance;
- (UIImage *)currentCVbuffer;
- (UIImage *)lastTriggeredImage;
- (UIImage *)setLastTriggeredImage;
- (void)addCVimage:(CIImage *)image withFrame:(CGRect)frame andTime:(CMTime)time;

@property (nonatomic, assign) id<OpenCVManagerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
