//
//  HJCameraManager.h
//  HJBox
//
//  Created by Tae Hyun Na on 2013. 11. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

@import UIKit;
@import AVFoundation;

#define     HJCameraManagerNotification                     @"HJCameraManagerNotification"
#define     HJCameraManagerNotifyParameterKeyStatus         @"HJCameraManagerNotifyParameterKeyStatus"
#define     HJCameraManagerNotifyParameterKeyImage          @"HJCameraManagerNotifyParameterKeyImage"
#define     HJCameraManagerNotifyParameterKeyFileUrl        @"HJCameraManagerNotifyParameterKeyFileUrl"

typedef NS_ENUM(NSInteger, HJCameraManagerStatus)
{
    HJCameraManagerStatusDummy,
    HJCameraManagerStatusIdle,
    HJCameraManagerStatusRunning,
    HJCameraManagerStatusStillImageCaptured,
    HJCameraManagerStatusStillImageCaptureFailed,
    HJCameraManagerStatusPreviewImageCaptured,
    HJCameraManagerStatusVideoRecordBegan,
    HJCameraManagerStatusVideoRecordEnded,
    HJCameraManagerStatusVideoRecordFailed,
    HJCameraManagerStatusMediaProcessingDone,
    HJCameraManagerStatusMediaProcessingFailed,
    HJCameraManagerStatusStartFailedWithInternalError,
    HJCameraManagerStatusStartFailedWithAccessDenied,
    kCountOfHJCameraManagerStatus
};

typedef NS_ENUM(NSInteger, HJCameraManagerFlashMode)
{
    HJCameraManagerFlashModeOff,
    HJCameraManagerFlashModeOn,
    HJCameraManagerFlashModeAuto
};

typedef NS_ENUM(NSInteger, HJCameraManagerTorchMode)
{
    HJCameraManagerTorchModeOff,
    HJCameraManagerTorchModeOn,
    HJCameraManagerTorchModeAuto
};

typedef NS_ENUM(NSInteger, HJCameraManagerDevicePosition)
{
    HJCameraManagerDevicePositionUnspecified,
    HJCameraManagerDevicePositionBack,
    HJCameraManagerDevicePositionFront
};

typedef NS_ENUM(NSInteger, HJCameraManagerVideoOrientation)
{
    HJCameraManagerVideoOrientationPortrait,
    HJCameraManagerVideoOrientationPortraitUpsideDown,
    HJCameraManagerVideoOrientationLandscapeRight,
    HJCameraManagerVideoOrientationLandscapeLeft
};

typedef NS_ENUM(NSInteger, HJCameraManagerPreviewContentMode)
{
    HJCameraManagerPreviewContentModeResizeAspect,
    HJCameraManagerPreviewContentModeResizeAspectFill,
    HJCameraManagerPreviewContentModeResize
};

typedef NS_ENUM(NSInteger, HJCameraManagerImageProcessingType)
{
    HJCameraManagerImageProcessingTypePass,
    HJCameraManagerImageProcessingTypeResizeByGivenWidth,
    HJCameraManagerImageProcessingTypeResizeByGivenHeight,
    HJCameraManagerImageProcessingTypeResizeByGivenSize,
    HJCameraManagerImageProcessingTypeResizeByGivenRate,
    HJCameraManagerImageProcessingTypeCropCenterSquare,
    HJCameraManagerImageProcessingTypeCropCenterSquareAndResizeByGivenWidth
};

typedef void(^HJCameraManagerCompletion)(HJCameraManagerStatus, UIImage * _Nullable, NSURL * _Nullable);

@interface HJCameraManager : NSObject

+ (HJCameraManager * _Nonnull)sharedManager;

- (BOOL)startWithPreviewViewForPhoto:(UIView * _Nullable)previewView;
- (BOOL)startWithPreviewViewForVideo:(UIView * _Nullable)previewView enableAudio:(BOOL)enableAudio;
- (BOOL)startWithPreviewView:(UIView * _Nullable)previewView preset:(NSString * _Nullable)preset enableVideo:(BOOL)enableVideo enableAudio:(BOOL)enableAudio;
- (void)stop;
- (BOOL)toggleCamera;
- (void)captureStillImage:(HJCameraManagerCompletion _Nullable)completion;
- (void)capturePreviewImage:(HJCameraManagerCompletion _Nullable)completion;
- (BOOL)recordVideoToFileUrl:(NSURL * _Nullable)fileUrl;
- (void)stopRecordingVideo:(HJCameraManagerCompletion _Nullable)completion;
- (void)setVideoOrientationByDeviceOrietation:(UIDeviceOrientation)deviceOrientation;

+ (void)processingImage:(UIImage * _Nullable)image type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize completion:(HJCameraManagerCompletion _Nullable)completion;
+ (void)processingVideo:(NSURL * _Nullable)fileUrl toOutputFileUrl:(NSURL * _Nullable)outputFileUrl type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString * _Nullable)preset completion:(HJCameraManagerCompletion _Nullable)completion;

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) NSInteger countOfCamera;
@property (nonatomic, assign) HJCameraManagerFlashMode flashMode;
@property (nonatomic, assign) HJCameraManagerTorchMode torchMode;
@property (nonatomic, assign) HJCameraManagerDevicePosition devicePosition;
@property (nonatomic, assign) HJCameraManagerVideoOrientation videoOrientation;
@property (nonatomic, assign) HJCameraManagerPreviewContentMode previewContentMode;
@property (nonatomic, assign) BOOL notifyPreviewImage;
@property (nonatomic, readonly) BOOL isVideoRecording;

@end
