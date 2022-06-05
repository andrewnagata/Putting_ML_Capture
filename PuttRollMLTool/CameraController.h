//
//  CameraController.h
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
#endif

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@import CoreMedia;

NS_ASSUME_NONNULL_BEGIN

@protocol CameraControllerDelegate <NSObject>
- (void)onCaptureSessionStarted;
@end

@interface CameraController : NSObject

@property (nonatomic, assign) id<CameraControllerDelegate> delegate;

- (instancetype)initCamera;
- (void)stopCaptureSession;
- (void)startCaptureSession;
+ (AVCaptureDevice *)frontCaptureDevice;
- (AVCaptureDeviceFormat *)getVideoFormat;

@end

NS_ASSUME_NONNULL_END
