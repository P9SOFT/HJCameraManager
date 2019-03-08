//
//  HJCameraManager.m
//  HJBox
//
//  Created by Tae Hyun Na on 2013. 11. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "HJCameraManager.h"

@interface HJCameraManager () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    HJCameraManagerStatus       _status;
    AVCaptureSession            *_session;
    AVCaptureVideoPreviewLayer  *_videoPreviewLayer;
    AVCaptureDeviceInput        *_deviceInput;
    AVCaptureStillImageOutput   *_stillImageOutput;
    AVCaptureVideoDataOutput    *_videoOutput;
    dispatch_queue_t            _serialQueue;
    NSMutableArray              *_capturePreviewQueue;
    NSLock                      *_lock;
}

- (void)postNotifyWithStatus:(HJCameraManagerStatus)status image:(UIImage *)image completion:(HJCameraManagerCompletion)completion;
- (AVCaptureConnection *)captureConnection;
- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@implementation HJCameraManager

@dynamic countOfCamera;
@dynamic flashMode;
@dynamic devicePosition;

- (id)init
{
    if( (self = [super init]) != nil ) {
        _status = HJCameraManagerStatusIdle;
        _serialQueue = dispatch_queue_create("p9soft.manager.hjcamera", DISPATCH_QUEUE_SERIAL);
        if( (_capturePreviewQueue = [NSMutableArray new]) == nil ) {
            return nil;
        }
        if( (_lock = [[NSLock alloc] init]) == nil ) {
            return nil;
        }
    }
    
    return self;
}

+ (HJCameraManager *)sharedManager
{
    static dispatch_once_t once;
    static HJCameraManager *sharedInstance;
    dispatch_once(&once, ^{sharedInstance = [[self alloc] init];});
    return sharedInstance;
}

- (BOOL)startWithPreviewView:(UIView *)previewView preset:(NSString *)preset
{
    if( previewView == nil ) {
        return NO;
    }
    
    AVCaptureDevice *captureDevice;
    NSError *error = nil;
    
    [_lock lock];
    
    if( _status != HJCameraManagerStatusIdle ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    if( (_session = [[AVCaptureSession alloc] init]) == nil ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    if( [preset length] > 0 ) {
        _session.sessionPreset = preset;
    }
    if( (captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]) == nil ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    if( (_videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session]) == nil ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    _videoPreviewLayer.frame = previewView.bounds;
    [previewView.layer addSublayer: _videoPreviewLayer];
    if( (_deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error]) == nil ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    if( [_session canAddInput:_deviceInput] == NO ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    [_session addInput:_deviceInput];
    if( (_stillImageOutput = [[AVCaptureStillImageOutput alloc] init]) == nil ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    [_stillImageOutput setOutputSettings:@{AVVideoCodecJPEG:AVVideoCodecKey}];
    if( [_session canAddOutput:_stillImageOutput] == NO ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    [_session addOutput:_stillImageOutput];
    if( (_videoOutput = [[AVCaptureVideoDataOutput alloc] init]) == nil ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    _videoOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    [_videoOutput setSampleBufferDelegate:self queue:_serialQueue];
    if( [_session canAddOutput:_videoOutput] == NO ) {
        goto START_WITH_PREVIEW_FAILED;
    }
    [_session addOutput:_videoOutput];
    [_session startRunning];
    _status = HJCameraManagerStatusRunning;
    [self postNotifyWithStatus:HJCameraManagerStatusRunning image:nil completion:nil];
    
    [_lock unlock];
    
    return YES;
    
START_WITH_PREVIEW_FAILED:
    
    if( _session != nil ) {
        _session = nil;
    }
    if( _videoPreviewLayer != nil ) {
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = nil;
    }
    if( _deviceInput != nil ) {
        _deviceInput = nil;
    }
    if( _stillImageOutput != nil ) {
        _stillImageOutput = nil;
    }
    _status = HJCameraManagerStatusAccessDenied;
    
    [_lock unlock];
    
    [self postNotifyWithStatus:HJCameraManagerStatusAccessDenied image:nil completion:nil];
    
    return NO;
}

- (void)stop
{
    [_lock lock];
    
    if( _status == HJCameraManagerStatusRunning ) {
        [_session stopRunning];
        _session = nil;
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = nil;
        _deviceInput = nil;
        _stillImageOutput = nil;
        _status = HJCameraManagerStatusIdle;
        [self postNotifyWithStatus: HJCameraManagerStatusIdle image:nil completion:nil];
    }
    
    [_lock unlock];
}

- (BOOL)toggleCamera
{
    BOOL result = NO;
    
    [_lock lock];
    
    if( _status == HJCameraManagerStatusRunning ) {
        self.devicePosition = ([[_deviceInput device] position] == AVCaptureDevicePositionFront) ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
        result = YES;
    }
    
    [_lock unlock];
    
    return result;
}

- (BOOL)toggleCameraToFront
{
    BOOL result = NO;
    
    [_lock lock];
    
    if( _status == HJCameraManagerStatusRunning ) {
        self.devicePosition = AVCaptureDevicePositionFront;
        result = YES;
    }
    
    [_lock unlock];
    
    return result;
}

- (BOOL)toggleCameraToBack
{
    BOOL result = NO;

    [_lock lock];

    if( _status == HJCameraManagerStatusRunning ) {
        self.devicePosition = AVCaptureDevicePositionBack;
        result = YES;
    }

    [_lock unlock];

    return result;
}

- (void)captureStillImage:(HJCameraManagerCompletion)completion
{
    [_lock lock];
    
    if( _status != HJCameraManagerStatusRunning ) {
        [_lock unlock];
        if( completion != nil ) {
            completion(HJCameraManagerStatusInternalError, nil);
        }
        return;
    }
    
    AVCaptureConnection *videoConnection = [self captureConnection];
    if( videoConnection == nil ) {
        [_lock unlock];
        if( completion != nil ) {
            completion(HJCameraManagerStatusInternalError, nil);
        }
        return;
    }
    
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection: videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        UIImage *image = nil;
        if( imageDataSampleBuffer != NULL ) {
            NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            if( data != nil ) {
                image = [[UIImage alloc] initWithData:data];
            }
        }
        if( image != nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:image completion:completion];
        } else {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil completion:completion];
        }
    }];
    
    [_lock unlock];
}

- (void)capturePreviewImage:(HJCameraManagerCompletion)completion
{
    if( completion == nil ) {
        return;
    }
    [_lock lock];
    [_capturePreviewQueue addObject:completion];
    [_lock unlock];
}

- (void)postNotifyWithStatus:(HJCameraManagerStatus)status image:(UIImage *)image completion:(HJCameraManagerCompletion)completion
{
    NSMutableDictionary *paramDict = [NSMutableDictionary new];
    paramDict[HJCameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
    if( image != nil ) {
        paramDict[HJCameraManagerNotifyParameterKeyStillImage] = image;
    }
    dispatch_async( dispatch_get_main_queue(), ^{
        if( completion != nil ) {
            completion(status, image);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:HJCameraManagerNotification object:self userInfo:paramDict];
    });
}
    
- (AVCaptureConnection *)captureConnection
{
    AVCaptureConnection *videoConnection = nil;
    for( AVCaptureConnection *connection in _stillImageOutput.connections ) {
        for( AVCaptureInputPort *inputPort in [connection inputPorts] ) {
            if( [[inputPort mediaType] isEqualToString:AVMediaTypeVideo] == YES ) {
                videoConnection = connection;
                break;
            }
        }
        if( videoConnection != nil ) {
            break;
        }
    }
    
    return videoConnection;
}

- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for( AVCaptureDevice *device in devices ) {
        if( [device position] == position ) {
            return device;
        }
    }
    
    return nil;
}
    
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if( sampleBuffer == NULL ) {
        return nil;
    }
    UIImage *image = nil;
    CVImageBufferRef cvImageBuff = CMSampleBufferGetImageBuffer(sampleBuffer);
    if( cvImageBuff != nil ) {
        CVPixelBufferLockBaseAddress(cvImageBuff, kCVPixelBufferLock_ReadOnly);
        void *baseAddress = CVPixelBufferGetBaseAddress(cvImageBuff);
        size_t w = CVPixelBufferGetWidth(cvImageBuff);
        size_t h = CVPixelBufferGetHeight(cvImageBuff);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(cvImageBuff);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(baseAddress, w, h, 8, bytesPerRow, colorSpace, (kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little));
        CGImageRef imageRef = CGBitmapContextCreateImage(context);
        CVPixelBufferUnlockBaseAddress(cvImageBuff, kCVPixelBufferLock_ReadOnly);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        //image = [UIImage imageWithCGImage:imageRef];
        image =  [UIImage imageWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationRight];
        CGImageRelease(imageRef);
    }
    return image;
}

- (NSInteger)countOfCamera
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (HJCameraManagerFlashMode)flashMode
{
    HJCameraManagerFlashMode mode = HJCameraManagerFlashModeUnspecified;
    
    [_lock lock];
    
    AVCaptureDevice *captureDevice = [_deviceInput device];
    AVCaptureFlashMode flashMode = (captureDevice == nil) ? AVCaptureFlashModeOff : [captureDevice flashMode];
    switch( flashMode ) {
        case AVCaptureFlashModeOn :
            mode = HJCameraManagerFlashModeOn;
            break;
        case AVCaptureFlashModeOff :
            mode = HJCameraManagerFlashModeOff;
            break;
        case AVCaptureFlashModeAuto :
            mode = HJCameraManagerFlashModeAuto;
            break;
        default :
            break;
    }
    
    [_lock unlock];
    
    return mode;
}

- (void)setFlashMode:(HJCameraManagerFlashMode)flashMode
{
    AVCaptureFlashMode mode;
    switch( flashMode ) {
        case HJCameraManagerFlashModeOn :
            mode = AVCaptureFlashModeOn;
            break;
        case HJCameraManagerFlashModeOff :
            mode = AVCaptureFlashModeOff;
            break;
        case HJCameraManagerFlashModeAuto :
            mode = AVCaptureFlashModeAuto;
            break;
        default :
            return;
    }
    
    [_lock lock];
    
    AVCaptureDevice *captureDevice = [_deviceInput device];
    if( ([captureDevice hasFlash] == YES) && ([captureDevice isFlashModeSupported:mode] == YES) ) {
        if( _status == HJCameraManagerStatusRunning ) {
            NSError *error = nil;
            if( [captureDevice lockForConfiguration:&error] == YES ) {
                [captureDevice setFlashMode:mode];
                [captureDevice unlockForConfiguration];
            }
        }
    }
    
    [_lock unlock];
}

- (HJCameraManagerDevicePosition)devicePosition
{
    HJCameraManagerDevicePosition position = HJCameraManagerDevicePositionUnspecified;
    
    [_lock lock];
    
    AVCaptureDevicePosition devicePosition = (_deviceInput == nil) ? AVCaptureDevicePositionUnspecified : [[_deviceInput device] position];
    switch( devicePosition ) {
        case AVCaptureDevicePositionBack :
            position = HJCameraManagerDevicePositionBack;
            break;
        case AVCaptureDevicePositionFront :
            position = HJCameraManagerDevicePositionFront;
            break;
        default :
            break;
    }
    
    [_lock unlock];
    
    return position;
}

- (void)setDevicePosition:(HJCameraManagerDevicePosition)devicePosition
{
    AVCaptureDevicePosition position;
    switch( devicePosition ) {
        case HJCameraManagerDevicePositionBack :
            position = AVCaptureDevicePositionBack;
            break;
        case HJCameraManagerDevicePositionFront :
            position = AVCaptureDevicePositionFront;
            break;
        default :
            return;
    }
    
    [_lock lock];
    
    if( _status == HJCameraManagerStatusRunning ) {
        if( [[_deviceInput device] position] != position ) {
            AVCaptureDevice *captureDevice;
            if( (captureDevice = [self captureDeviceForPosition:position]) != nil ) {
                AVCaptureDeviceInput *captureDeviceInput;
                NSError *error = nil;
                if( (captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error]) != nil ) {
                    [_session beginConfiguration];
                    [_session removeInput:_deviceInput];
                    if( [_session canAddInput:captureDeviceInput] == NO ) {
                        [_session addInput:_deviceInput];
                    } else {
                        _deviceInput = captureDeviceInput;
                        [_session addInput:_deviceInput];
                        [_session commitConfiguration];
                    }
                }
            }
        }
    }
    
    [_lock unlock];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if( sampleBuffer == NULL ) {
        return;
    }
    UIImage *image = nil;
    [_lock lock];
    if( _capturePreviewQueue.count > 0 ) {
        HJCameraManagerCompletion completion = [_capturePreviewQueue firstObject];
        image = [self imageFromSampleBuffer:sampleBuffer];
        if( image != nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:image completion:completion];
        } else {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil completion:completion];
        }
        [_capturePreviewQueue removeObjectAtIndex:0];
    }
    [_lock unlock];
    if( _notifyPreviewImage == YES ) {
        if( image == nil ) {
            image = [self imageFromSampleBuffer:sampleBuffer];
        }
        if( image != nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusPreviewImageCaptured image:image completion:nil];
        }
    }
}

@end
