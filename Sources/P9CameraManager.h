//
//  P9CameraManager.h
//  
//
//  Created by Tae Hyun Na on 2013. 11. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

@import UIKit;
@import AVFoundation;

#define     P9CameraManagerNotification                     @"P9CameraManagerNotification"
#define     P9CameraManagerNotifyParameterKeyStatus         @"P9CameraManagerNotifyParameterKeyStatus"
#define     P9CameraManagerNotifyParameterKeyImage          @"P9CameraManagerNotifyParameterKeyImage"
#define     P9CameraManagerNotifyParameterKeyFileUrl        @"P9CameraManagerNotifyParameterKeyFileUrl"

typedef NS_ENUM(NSInteger, P9CameraManagerStatus)
{
    P9CameraManagerStatusDummy,
    P9CameraManagerStatusIdle,
    P9CameraManagerStatusRunning,
    P9CameraManagerStatusStillImageCaptured,
    P9CameraManagerStatusStillImageCaptureFailed,
    P9CameraManagerStatusPreviewImageCaptured,
    P9CameraManagerStatusVideoRecordBegan,
    P9CameraManagerStatusVideoRecordEnded,
    P9CameraManagerStatusVideoRecordFailed,
    P9CameraManagerStatusMediaProcessingDone,
    P9CameraManagerStatusMediaProcessingFailed,
    P9CameraManagerStatusStartFailedWithInternalError,
    P9CameraManagerStatusStartFailedWithAccessDenied
};

typedef NS_ENUM(NSInteger, P9CameraManagerFlashMode)
{
    P9CameraManagerFlashModeOff,
    P9CameraManagerFlashModeOn,
    P9CameraManagerFlashModeAuto
};

typedef NS_ENUM(NSInteger, P9CameraManagerTorchMode)
{
    P9CameraManagerTorchModeOff,
    P9CameraManagerTorchModeOn,
    P9CameraManagerTorchModeAuto
};

typedef NS_ENUM(NSInteger, P9CameraManagerDevicePosition)
{
    P9CameraManagerDevicePositionUnspecified,
    P9CameraManagerDevicePositionBack,
    P9CameraManagerDevicePositionFront
};

typedef NS_ENUM(NSInteger, P9CameraManagerVideoOrientation)
{
    P9CameraManagerVideoOrientationPortrait,
    P9CameraManagerVideoOrientationPortraitUpsideDown,
    P9CameraManagerVideoOrientationLandscapeRight,
    P9CameraManagerVideoOrientationLandscapeLeft
};

typedef NS_ENUM(NSInteger, P9CameraManagerPreviewContentMode)
{
    P9CameraManagerPreviewContentModeResizeAspect,
    P9CameraManagerPreviewContentModeResizeAspectFill,
    P9CameraManagerPreviewContentModeResize
};

typedef NS_ENUM(NSInteger, P9CameraManagerImageProcessingType)
{
    P9CameraManagerImageProcessingTypePass,
    P9CameraManagerImageProcessingTypeResizeByGivenWidth,
    P9CameraManagerImageProcessingTypeResizeByGivenHeight,
    P9CameraManagerImageProcessingTypeResizeByGivenSize,
    P9CameraManagerImageProcessingTypeResizeByGivenRate,
    P9CameraManagerImageProcessingTypeCropCenterSquare,
    P9CameraManagerImageProcessingTypeCropCenterSquareAndResizeByGivenWidth
};

typedef NS_ENUM(NSInteger, P9CameraManagerNotifyPreviewType)
{
    P9CameraManagerNotifyPreviewTypeNone,
    P9CameraManagerNotifyPreviewTypeImage
};

typedef void(^P9CameraManagerCompletion)(P9CameraManagerStatus, UIImage * _Nullable, NSURL * _Nullable);
typedef void(^P9CameraManagerPreviewHandler)(CMSampleBufferRef _Nullable);

@interface P9CameraManager : NSObject

+ (P9CameraManager * _Nonnull)sharedManager;

- (BOOL)startWithPreviewViewForPhoto:(UIView * _Nullable)previewView;
- (BOOL)startWithPreviewViewForVideo:(UIView * _Nullable)previewView enableAudio:(BOOL)enableAudio;
- (BOOL)startWithPreviewView:(UIView * _Nullable)previewView preset:(NSString * _Nullable)preset enableVideo:(BOOL)enableVideo enableAudio:(BOOL)enableAudio;
- (void)stop;
- (BOOL)toggleCamera;
- (void)captureStillImage:(P9CameraManagerCompletion _Nullable)completion;
- (void)capturePreviewImage:(P9CameraManagerCompletion _Nullable)completion;
- (BOOL)recordVideoToFileUrl:(NSURL * _Nullable)fileUrl;
- (void)stopRecordingVideo:(P9CameraManagerCompletion _Nullable)completion;
- (void)setVideoOrientationByDeviceOrietation:(UIDeviceOrientation)deviceOrientation;
- (void)setPreviewHandler:(P9CameraManagerPreviewHandler _Nullable)previewHandler;

+ (void)processingImage:(UIImage * _Nullable)image type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize completion:(P9CameraManagerCompletion _Nullable)completion;
+ (void)processingVideo:(NSURL * _Nullable)fileUrl toOutputFileUrl:(NSURL * _Nullable)outputFileUrl type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString * _Nullable)preset completion:(P9CameraManagerCompletion _Nullable)completion;

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) NSInteger countOfCamera;
@property (nonatomic, assign) P9CameraManagerFlashMode flashMode;
@property (nonatomic, assign) P9CameraManagerTorchMode torchMode;
@property (nonatomic, assign) P9CameraManagerDevicePosition devicePosition;
@property (nonatomic, assign) P9CameraManagerVideoOrientation videoOrientation;
@property (nonatomic, assign) P9CameraManagerPreviewContentMode previewContentMode;
@property (nonatomic, assign) P9CameraManagerNotifyPreviewType notifyPreviewType;
@property (nonatomic, readonly) BOOL isVideoRecording;

@end
