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
#define     HJCameraManagerNotifyParameterKeyStillImage     @"HJCameraManagerNotifyParameterKeyStillImage"

typedef NS_ENUM(NSInteger, HJCameraManagerStatus)
{
    HJCameraManagerStatusDummy,
    HJCameraManagerStatusIdle,
    HJCameraManagerStatusRunning,
    HJCameraManagerStatusStillImageCaptured,
    HJCameraManagerStatusStillImageCaptureFailed,
    HJCameraManagerStatusAccessDenied,
    HJCameraManagerStatusInternalError
};

typedef NS_ENUM(NSInteger, HJCameraManagerFlashMode)
{
    HJCameraManagerFlashModeUnspecified,
    HJCameraManagerFlashModeOff,
    HJCameraManagerFlashModeOn,
    HJCameraManagerFlashModeAuto
};

typedef NS_ENUM(NSInteger, HJCameraManagerDevicePosition)
{
    HJCameraManagerDevicePositionUnspecified,
    HJCameraManagerDevicePositionBack,
    HJCameraManagerDevicePositionFront
};

typedef void(^HJCameraManagerCompletion)(HJCameraManagerStatus, UIImage * _Nullable);

@interface HJCameraManager : NSObject

+ (HJCameraManager * _Nonnull)defaultHJCameraManager;

- (BOOL)startWithPreviewView:(UIView * _Nullable)previewView preset:(NSString * _Nullable)preset;
- (void)stop;
- (BOOL)toggleCamera;
- (BOOL)captureStillImage:(HJCameraManagerCompletion _Nullable)completion;

@property (nonatomic, readonly) HJCameraManagerStatus status;
@property (nonatomic, readonly) NSInteger countOfCamera;
@property (nonatomic, assign) HJCameraManagerFlashMode flashMode;
@property (nonatomic, assign) HJCameraManagerDevicePosition devicePosition;

@end
