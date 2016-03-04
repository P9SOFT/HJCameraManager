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

typedef enum _HJCameraManagerStatus_
{
    HJCameraManagerStatusDummy,
    HJCameraManagerStatusIdle,
    HJCameraManagerStatusRunning,
    HJCameraManagerStatusStillImageCaptured,
    HJCameraManagerStatusStillImageCaptureFailed,
    HJCameraManagerStatusAccessDenied,
    HJCameraManagerStatusInternalError,
    kCountOfHJCameraManagerStatus
    
} HJCameraManagerStatus;

typedef enum _HJCameraManagerFlashMode_
{
    HJCameraManagerFlashModeUnspecified,
    HJCameraManagerFlashModeOff,
    HJCameraManagerFlashModeOn,
    HJCameraManagerFlashModeAuto
    
} HJCameraManagerFlashMode;

typedef enum _HJCameraManagerDevicePosition_
{
    HJCameraManagerDevicePositionUnspecified,
    HJCameraManagerDevicePositionBack,
    HJCameraManagerDevicePositionFront
    
} HJCameraManagerDevicePosition;

typedef void(^HJCameraManagerCompletion)(HJCameraManagerStatus, UIImage *);

@interface HJCameraManager : NSObject

+ (HJCameraManager *)sharedManager;

- (BOOL)startWithPreviewView:(UIView *)previewView preset:(NSString *)preset;
- (void)stop;
- (BOOL)toggleCamera;
- (BOOL)captureStillImage:(HJCameraManagerCompletion)completion;

@property (nonatomic, readonly) HJCameraManagerStatus status;
@property (nonatomic, readonly) NSInteger countOfCamera;
@property (nonatomic, assign) HJCameraManagerFlashMode flashMode;
@property (nonatomic, assign) HJCameraManagerDevicePosition devicePosition;

@end
