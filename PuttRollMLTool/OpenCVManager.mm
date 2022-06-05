//
//  OpenCVManager.m
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 1/1/20.
//  Copyright © 2020 Andrew Nagata. All rights reserved.
//

#import "OpenCVManager.h"

#import <opencv2/imgcodecs/ios.h>
#include "opencv2/optflow.hpp"
#include "opencv2/imgproc.hpp"
#include "opencv2/videoio.hpp"
#include "opencv2/highgui.hpp"
#include <time.h>
#include <stdio.h>
#include <ctype.h>

// The following lines will help to mix C++ code
#include <stdlib.h>
using namespace std;
using namespace cv;

const double MHI_DURATION = 0.2;
const double DEFAULT_THRESHOLD = 40;
// ring image buffer
vector<Mat> buf;
int last = 0;
// temporary images
Mat mhi, mask, zplane, cvOutput;

@implementation OpenCVManager

+ (id)sharedInstance
{
    static OpenCVManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance initManager];
    });
    
    return sharedInstance;
}

- (void)initManager
{
    //Create queue for opencv processing
    imageProcessQueue = dispatch_queue_create("com.rollyk.imageProcessing", DISPATCH_QUEUE_SERIAL);
}

- (void)addCVimage:(CIImage *)image withFrame:(CGRect)frame andTime:(CMTime)time
{
    dispatch_async(imageProcessQueue, ^{
        
        @autoreleasepool {
            CIContext *context = [CIContext context];
            CGImageRef cgImage = [context createCGImage:image fromRect:frame];
            UIImage *imagecv = [UIImage imageWithCGImage:cgImage];
            
            Mat cvmat;
            UIImageToMat(imagecv, cvmat);
            
            [self processMotionHistory:cvmat atTime:time];
            
            CGImageRelease(cgImage);
            context = nil;
        }
    });
}

//OPENCV OPERATIONS
//*****************************************
- (void)processMotionHistory:(Mat &)image atTime:(CMTime)time;
{
    buf.resize(2);
    
    update_mhi(image, cvOutput, DEFAULT_THRESHOLD);
    
    UIImage *img = MatToUIImage(cvOutput);
    
    currentImage = img;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CVframe" object:self];
}

- (cv::Mat)rescaleFrame:(Mat &)frame
{
    int width = frame.size().width;
    int height = frame.size().height;
    
    float newWidth = 480;
    float scale = newWidth / (float)width;
    int newHeight = height * scale;
    
    Mat smaller;
    cv::Size size = cv::Size(newWidth, newHeight);
    
    cv::resize(frame, smaller, size, INTER_AREA);
    
    return smaller;
}

- (UIImage *)currentCVbuffer
{
    return currentImage;
}

- (UIImage *)setLastTriggeredImage
{
    lastTriggeredImage = currentImage;
    
    return lastTriggeredImage;
}

- (UIImage *)lastTriggeredImage
{
    return lastTriggeredImage;
}

static void update_mhi(const Mat& img, Mat& dst, int diff_threshold)
{
    double timestamp = (double)clock() / CLOCKS_PER_SEC; // get current time in seconds
    cv::Size size = img.size();
    int idx1 = last;
    
    // allocate images at the beginning or
    // reallocate them if the frame size is changed
    
    if (mhi.size() != size)
    {
        mhi = Mat::zeros(size, CV_32FC1);
        zplane = Mat::zeros(size, CV_8UC1);
        
        buf[0] = Mat::zeros(size, CV_8UC1);
        buf[1] = Mat::zeros(size, CV_8UC1);
    }
    
    cv::cvtColor(img, buf[last], COLOR_BGR2GRAY); // convert frame to grayscale
    
    int idx2 = (last + 1) % 2; // index of (last - (N-1))th frame
    last = idx2;
    
    Mat silh = buf[idx2];
    cv::absdiff(buf[idx1], buf[idx2], silh); // get difference between frames
    
    cv::threshold(silh, silh, diff_threshold, 1, THRESH_BINARY); // and threshold it
    cv::motempl::updateMotionHistory(silh, mhi, timestamp, MHI_DURATION); // update MHI
    
    // convert MHI to blue 8u image
    mhi.convertTo(mask, CV_8U, 255. / MHI_DURATION, (MHI_DURATION - timestamp)*255. / MHI_DURATION);
    
    Mat planes[] = { mask, zplane, zplane };
    merge(planes, 1, dst);
}

//PIXEL HELPERS
//********************************
void assertCropAndScaleValid(CVPixelBufferRef pixelBuffer, CGRect cropRect, CGSize scaleSize)
{
    CGFloat originalWidth = (CGFloat)CVPixelBufferGetWidth(pixelBuffer);
    CGFloat originalHeight = (CGFloat)CVPixelBufferGetHeight(pixelBuffer);
    
    assert(CGRectContainsRect(CGRectMake(0, 0, originalWidth, originalHeight), cropRect));
    assert(scaleSize.width > 0 && scaleSize.height > 0);
}

CVPixelBufferRef createCroppedPixelBufferCoreImage(CVPixelBufferRef pixelBuffer,
                                                   CGRect cropRect,
                                                   CGSize scaleSize,
                                                   CIContext *context)
{
    
    assertCropAndScaleValid(pixelBuffer, cropRect, scaleSize);
    
    CIImage *image = [CIImage imageWithCVImageBuffer:pixelBuffer];
    //image = [image imageByCroppingToRect:cropRect];
    
    CGFloat scaleX = scaleSize.width / CGRectGetWidth(image.extent);
    CGFloat scaleY = scaleSize.height / CGRectGetHeight(image.extent);
    
    image = [image imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
    
    // Due to the way [CIContext:render:toCVPixelBuffer] works, we need to translate the image so the cropped section is at the origin
    image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-image.extent.origin.x, -image.extent.origin.y)];
    
    CVPixelBufferRef output = NULL;
    
    CVPixelBufferCreate(nil,
                        CGRectGetWidth(image.extent),
                        CGRectGetHeight(image.extent),
                        CVPixelBufferGetPixelFormatType(pixelBuffer),
                        nil,
                        &output);
    
    if (output != NULL)
    {
        [context render:image toCVPixelBuffer:output];
    }
    
    return output;
}

@end
