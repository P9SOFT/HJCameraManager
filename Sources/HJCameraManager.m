//
//  HJCameraManager.m
//  HJBox
//
//  Created by Tae Hyun Na on 2013. 11. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "HJCameraManager.h"

@interface HJCameraManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate>
{
    HJCameraManagerFlashMode            _flashMode;
    HJCameraManagerTorchMode            _torchMode;
    HJCameraManagerDevicePosition       _devicePosition;
    HJCameraManagerVideoOrientation     _videoOrientation;
    HJCameraManagerPreviewContentMode   _previewContentMode;
}

@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, strong) dispatch_queue_t videoOutputSerialQueue;
@property (nonatomic, strong) NSMutableArray *capturePreviewCompletionQueue;
@property (nonatomic, strong) NSMutableArray *moveFileSaveToPhotosAlbumCompletionQueue;
@property (nonatomic, strong) NSMutableArray *photoCaptureCompletionQueue;

- (void)reset;
- (void)postNotifyWithStatus:(HJCameraManagerStatus)status image:(UIImage *)image fileUrl:(NSURL *)fileUrl completion:(HJCameraManagerCompletion)completion;
- (AVCaptureConnection *)videoConnectionOfCaptureOutput:(AVCaptureOutput *)output;
- (BOOL)updateVideoOrientationForCaptureOutput:(AVCaptureOutput *)output;
- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
+ (HJCameraManagerVideoOrientation)orientationFor:(CGAffineTransform)preferredTransform;
+ (CGAffineTransform)transformFor:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform;
+ (CGSize)sizeForCenterCrop:(CGSize)naturalSize;
+ (CGAffineTransform)transformForCenterCrop:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform;
+ (dispatch_queue_t)imageProcessQueue;
+ (UIImage *)orientationFixImage:(UIImage *)image videoOrientation:(HJCameraManagerVideoOrientation)videoOrientation;
+ (UIImage *)processingImage:(UIImage *)image type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize;
+ (UIImage *)cropImage:(UIImage *)image cropRect:(CGRect)cropRect;
+ (AVAssetExportSession *)exportSessionForProcessingVideo:(NSURL *)fileUrl toOutputFileUrl:(NSURL *)outputFileUrl type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString *)preset;

@end

@implementation HJCameraManager

@dynamic countOfCamera;
@dynamic flashMode;
@dynamic torchMode;
@dynamic devicePosition;
@dynamic videoOrientation;
@dynamic previewContentMode;
@dynamic isVideoRecording;

- (instancetype)init
{
    if( (self = [super init]) != nil ) {
        _isRunning = NO;
        _flashMode = HJCameraManagerFlashModeOff;
        _torchMode = HJCameraManagerTorchModeOff;
        _devicePosition = HJCameraManagerDevicePositionBack;
        _videoOrientation = HJCameraManagerVideoOrientationPortrait;
        _previewContentMode = HJCameraManagerPreviewContentModeResizeAspect;
        _videoOutputSerialQueue = dispatch_queue_create("p9soft.manager.hjcamera-videoOutput", DISPATCH_QUEUE_SERIAL);
        if( (_capturePreviewCompletionQueue = [NSMutableArray new]) == nil ) {
            return nil;
        }
        if( (_moveFileSaveToPhotosAlbumCompletionQueue = [NSMutableArray new]) == nil ) {
            return nil;
        }
        if( (_photoCaptureCompletionQueue = [NSMutableArray new]) == nil ) {
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

- (BOOL)startWithPreviewViewForPhoto:(UIView * _Nullable)previewView
{
    return [self startWithPreviewView:previewView preset:AVCaptureSessionPresetPhoto enableVideo:NO enableAudio:NO];
}

- (BOOL)startWithPreviewViewForVideo:(UIView * _Nullable)previewView enableAudio:(BOOL)enableAudio
{
    return [self startWithPreviewView:previewView preset:AVCaptureSessionPresetHigh enableVideo:YES enableAudio:enableAudio];
}

- (BOOL)startWithPreviewView:(UIView * _Nullable)previewView preset:(NSString * _Nullable)preset enableVideo:(BOOL)enableVideo enableAudio:(BOOL)enableAudio
{
    if( (previewView == nil) || (preset.length == 0) ) {
        [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithInternalError image:nil fileUrl:nil completion:nil];
        return NO;
    }
    
    AVCaptureFlashMode flashMode = AVCaptureFlashModeOff;
    switch( _flashMode ) {
        case HJCameraManagerFlashModeOn :
            flashMode = AVCaptureFlashModeOn;
            break;
        case HJCameraManagerFlashModeOff :
            flashMode = AVCaptureFlashModeOff;
            break;
        default :
            break;
    }
    
    AVCaptureTorchMode torchMode = AVCaptureTorchModeOff;
    switch( _torchMode ) {
        case HJCameraManagerTorchModeOn :
            torchMode = AVCaptureTorchModeOn;
            break;
        case HJCameraManagerTorchModeOff :
            torchMode = AVCaptureTorchModeOff;
            break;
        default :
            break;
    }
    
    AVCaptureDevicePosition position = AVCaptureDevicePositionUnspecified;
    switch( _devicePosition ) {
        case HJCameraManagerDevicePositionBack :
            position = AVCaptureDevicePositionBack;
            break;
        case HJCameraManagerDevicePositionFront :
            position = AVCaptureDevicePositionFront;
            break;
        default :
            break;
    }
    
    @synchronized (self) {
        
        if( _isRunning == YES ) {
            return NO;
        }
        if( (_session = [[AVCaptureSession alloc] init]) == nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithInternalError image:nil fileUrl:nil completion:nil];
            return NO;
        }
        
        [_session beginConfiguration];
        
        if( [self.session canSetSessionPreset:preset] == NO ) {
            [self reset];
            [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
            return NO;
        }
        _session.sessionPreset = preset;
        
        AVCaptureDevice *captureDevice = [self captureDeviceForPosition:position];
        if( captureDevice != nil ) {
            _captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
            if( (captureDevice.hasFlash == YES) && ([captureDevice isFlashModeSupported:flashMode] == YES) ) {
                if( [captureDevice lockForConfiguration:nil] == YES ) {
                    [captureDevice setFlashMode:flashMode];
                    [captureDevice setTorchMode:torchMode];
                    [captureDevice unlockForConfiguration];
                }
            }
        }
        if( (_captureDeviceInput == nil) || ([_session canAddInput:_captureDeviceInput] == NO) ) {
            [self reset];
            [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
            return NO;
        }
        [_session addInput:_captureDeviceInput];
        
        if (@available(iOS 10.0, *)) {
            _photoOutput = [[AVCapturePhotoOutput alloc] init];
            if( (_photoOutput == nil) || ([_session canAddOutput:_photoOutput] == NO) ) {
                [self reset];
                [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addOutput:_photoOutput];
        } else {
            if( (_stillImageOutput = [[AVCaptureStillImageOutput alloc] init]) == nil ) {
                [self reset];
                [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_stillImageOutput setOutputSettings:@{AVVideoCodecJPEG:AVVideoCodecKey}];
            if( [_session canAddOutput:_stillImageOutput] == NO ) {
                [self reset];
                [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addOutput:_stillImageOutput];
        }
        
        if( enableVideo == NO ) {
            if( (_videoOutput = [[AVCaptureVideoDataOutput alloc] init]) != nil ) {
                _videoOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
                [_videoOutput setSampleBufferDelegate:self queue:_videoOutputSerialQueue];
                if( [_session canAddOutput:_videoOutput] == YES ) {
                    [_session addOutput:_videoOutput];
                } else {
                    _videoOutput = nil;
                }
            }
        } else {
            _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
            if( (_movieFileOutput == nil) || ([_session canAddOutput:_movieFileOutput] == NO) ) {
                [self reset];
                [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addOutput:_movieFileOutput];
        }
        
        if( enableAudio == YES ) {
            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            if( (audioDevice == nil) || ((_audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil]) == nil) || ([_session canAddInput:_audioDeviceInput] == NO) ) {
                [self reset];
                [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addInput:_audioDeviceInput];
        }
        
        [_session commitConfiguration];
        
        if( (_videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session]) == nil ) {
            [self reset];
            [self postNotifyWithStatus:HJCameraManagerStatusStartFailedWithInternalError image:nil fileUrl:nil completion:nil];
            return NO;
        }
        
        AVLayerVideoGravity gravity = AVLayerVideoGravityResizeAspect;
        switch( _previewContentMode ) {
            case HJCameraManagerPreviewContentModeResizeAspectFill :
                gravity = AVLayerVideoGravityResizeAspectFill;
                break;
            case HJCameraManagerPreviewContentModeResize :
                gravity = AVLayerVideoGravityResize;
                break;
            default :
                break;
        }
        _videoPreviewLayer.videoGravity = gravity;
        if( _videoPreviewLayer.connection.isVideoOrientationSupported == YES ) {
            AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
            switch( _videoOrientation ) {
                case HJCameraManagerVideoOrientationPortraitUpsideDown :
                    orientation = AVCaptureVideoOrientationPortraitUpsideDown;
                    break;
                case HJCameraManagerVideoOrientationLandscapeLeft :
                    orientation = AVCaptureVideoOrientationLandscapeLeft;
                    break;
                case HJCameraManagerVideoOrientationLandscapeRight :
                    orientation = AVCaptureVideoOrientationLandscapeRight;
                    break;
                default :
                    break;
            }
            _videoPreviewLayer.connection.videoOrientation = orientation;
        }
        _videoPreviewLayer.bounds = previewView.bounds;
        _videoPreviewLayer.position = CGPointMake(CGRectGetMidX(_videoPreviewLayer.bounds), CGRectGetMidY(_videoPreviewLayer.bounds));
        [previewView.layer addSublayer: _videoPreviewLayer];
        
        [_session startRunning];
        _isRunning = YES;
        
    }
    
    [self postNotifyWithStatus:HJCameraManagerStatusRunning image:nil fileUrl:nil completion:nil];
    
    return YES;
}

- (void)stop
{
    @synchronized (self) {
        if( ([_movieFileOutput connectionWithMediaType:AVMediaTypeVideo].active == YES) && (_movieFileOutput.isRecording == YES) ) {
            [_movieFileOutput stopRecording];
        }
        [_session stopRunning];
        [self reset];
        _isRunning = NO;
    }
    [self postNotifyWithStatus: HJCameraManagerStatusIdle image:nil fileUrl:nil completion:nil];
}

- (BOOL)toggleCamera
{
    @synchronized (self) {
        if( _isRunning == YES ) {
            self.devicePosition = ([[_captureDeviceInput device] position] == AVCaptureDevicePositionFront) ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
            return YES;
        }
    }
    return NO;
}

- (BOOL)toggleCameraToFront
{
    @synchronized (self) {
        if( _isRunning == YES ) {
            self.devicePosition = AVCaptureDevicePositionFront;
            return YES;
        }
    }
    return NO;
}

- (BOOL)toggleCameraToBack
{
    @synchronized (self) {
        if( _isRunning == YES ) {
            self.devicePosition = AVCaptureDevicePositionBack;
            return YES;
        }
    }
    return NO;
}

- (void)captureStillImage:(HJCameraManagerCompletion _Nullable)completion
{
    @synchronized (self) {
        if (@available(iOS 10.0, *)) {
            if( (_isRunning == NO) || (_photoOutput == nil) ) {
                [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                return;
            }
            AVCapturePhotoSettings *settings = [[AVCapturePhotoSettings alloc] init];
            if( settings.availablePreviewPhotoPixelFormatTypes.count > 0 ) {
                settings.previewPhotoFormat = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
            }
            if( completion != nil ) {
                [_photoCaptureCompletionQueue addObject:completion];
            }
            if( [self updateVideoOrientationForCaptureOutput:_photoOutput] == NO ) {
                [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:nil fileUrl:nil completion:completion];
                return;
            }
            [_photoOutput capturePhotoWithSettings:settings delegate:self];
        } else {
            if( (_isRunning == NO) || (_stillImageOutput == nil) ) {
                [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                return;
            }
            AVCaptureConnection *connection = [self videoConnectionOfCaptureOutput:_stillImageOutput];
            if( (connection == nil) || ([self updateVideoOrientationForCaptureOutput:_stillImageOutput] == NO) ) {
                [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:nil fileUrl:nil completion:completion];
                return;
            }
            [_stillImageOutput captureStillImageAsynchronouslyFromConnection: connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                if( imageDataSampleBuffer == NULL ) {
                    [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                    return;
                }
                UIImage *image = nil;
                NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                if( data != nil ) {
                    image = [[UIImage alloc] initWithData:data];
                }
                if( image != nil ) {
                    [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:image fileUrl:nil completion:completion];
                } else {
                    [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                }
            }];
        }
    }
}

- (void)capturePreviewImage:(HJCameraManagerCompletion _Nullable)completion
{
    @synchronized (self) {
        if( (_isRunning == NO) || (_videoOutput == nil) ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
            return;
        }
        [_capturePreviewCompletionQueue addObject:(completion != nil ? @[@(self.videoOrientation), completion] : @[@(self.videoOrientation)])];
    }
}

- (BOOL)recordVideoToFileUrl:(NSURL * _Nullable)fileUrl
{
    if( fileUrl == nil ) {
        [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordFailed image:nil fileUrl:nil completion:nil];
        return NO;
    }
    
    @synchronized (self) {
        if( (_isRunning == NO) || ([_movieFileOutput connectionWithMediaType:AVMediaTypeVideo].active == NO) || (_movieFileOutput.isRecording == YES) ) {
            [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordFailed image:nil fileUrl:fileUrl completion:nil];
            return NO;
        }
        if( [self updateVideoOrientationForCaptureOutput:_movieFileOutput] == NO ) {
            [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordFailed image:nil fileUrl:fileUrl completion:nil];
            return NO;
        }
        [_movieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    
    return YES;
}

- (void)stopRecordingVideo:(HJCameraManagerCompletion _Nullable)completion
{
    @synchronized (self) {
        if( (_isRunning == NO) || (_movieFileOutput.isRecording == NO) ) {
            [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordFailed image:nil fileUrl:_movieFileOutput.outputFileURL completion:completion];
            return;
        }
        [_moveFileSaveToPhotosAlbumCompletionQueue addObject:completion];
        [_movieFileOutput stopRecording];
    }
}

- (void)setVideoOrientationByDeviceOrietation:(UIDeviceOrientation)deviceOrientation
{
    switch( deviceOrientation ) {
        case UIDeviceOrientationPortrait :
            self.videoOrientation = HJCameraManagerVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown :
            self.videoOrientation = HJCameraManagerVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft :
            self.videoOrientation = HJCameraManagerVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight :
            self.videoOrientation = HJCameraManagerVideoOrientationLandscapeLeft;
            break;
        default :
            break;
    }
}

+ (dispatch_queue_t)imageProcessQueue
{
    static dispatch_once_t once;
    static dispatch_queue_t imageProcessSerialQueue;
    dispatch_once(&once, ^{imageProcessSerialQueue = dispatch_queue_create("p9soft.manager.hjcamera-imageProcess", DISPATCH_QUEUE_SERIAL);});
    return imageProcessSerialQueue;
}

+ (void)processingImage:(UIImage * _Nullable)image type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize completion:(HJCameraManagerCompletion _Nullable)completion
{
    if( completion == nil ) {
        return;
    }
    if( image == nil ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(HJCameraManagerStatusMediaProcessingFailed, nil, nil);
        });
        return;
    }
    dispatch_async([HJCameraManager imageProcessQueue], ^{
        UIImage *processedImage = [self processingImage:image type:type referenceSize:referenceSize ];
        HJCameraManagerStatus status = (processedImage != nil ? HJCameraManagerStatusMediaProcessingDone : HJCameraManagerStatusMediaProcessingFailed);
        NSMutableDictionary *paramDict = [NSMutableDictionary new];
        paramDict[HJCameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
        if( processedImage != nil ) {
            paramDict[HJCameraManagerNotifyParameterKeyImage] = processedImage;
        }
        dispatch_async( dispatch_get_main_queue(), ^{
            if( completion != nil ) {
                completion(status, processedImage, nil);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:HJCameraManagerNotification object:self userInfo:paramDict];
        });
    });
}

+ (void)processingVideo:(NSURL * _Nullable)fileUrl toOutputFileUrl:(NSURL * _Nullable)outputFileUrl type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString *)preset completion:(HJCameraManagerCompletion _Nullable)completion
{
    if( (fileUrl == nil) || (outputFileUrl == nil) || (preset == nil) ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(HJCameraManagerStatusMediaProcessingFailed, nil, outputFileUrl);
            });
        }
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVAssetExportSession *exportSession = nil;
        NSMutableDictionary *paramDict = [NSMutableDictionary new];
        HJCameraManagerStatus status = HJCameraManagerStatusMediaProcessingFailed;
        if( type == HJCameraManagerImageProcessingTypePass ) {
            if( [NSFileManager.defaultManager copyItemAtURL:fileUrl toURL:outputFileUrl error:nil] == YES ) {
                status = HJCameraManagerStatusMediaProcessingDone;
            }
        } else {
            if( (exportSession = [self exportSessionForProcessingVideo:fileUrl toOutputFileUrl:outputFileUrl type:type referenceSize:referenceSize preset:preset]) != nil ) {
                status = HJCameraManagerStatusMediaProcessingDone;
            }
        }
        paramDict[HJCameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
        paramDict[HJCameraManagerNotifyParameterKeyFileUrl] = outputFileUrl;
        if( exportSession != nil ) {
            [[NSFileManager defaultManager] removeItemAtURL:outputFileUrl error:nil];
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if( completion != nil ) {
                        completion(status, nil, outputFileUrl);
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:HJCameraManagerNotification object:self userInfo:paramDict];
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if( completion != nil ) {
                    completion(status, nil, outputFileUrl);
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:HJCameraManagerNotification object:self userInfo:paramDict];
            });
        }
    });
}

- (void)reset
{
    [_capturePreviewCompletionQueue removeAllObjects];
    if( _videoPreviewLayer != nil ) {
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = nil;
    }
    _captureDeviceInput = nil;
    _stillImageOutput = nil;
    _photoOutput = nil;
    _videoOutput = nil;
    _movieFileOutput = nil;
    _audioDeviceInput = nil;
    _session = nil;
}

- (void)postNotifyWithStatus:(HJCameraManagerStatus)status image:(UIImage *)image fileUrl:(NSURL *)fileUrl completion:(HJCameraManagerCompletion)completion
{
    NSMutableDictionary *paramDict = [NSMutableDictionary new];
    paramDict[HJCameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
    if( image != nil ) {
        paramDict[HJCameraManagerNotifyParameterKeyImage] = image;
    }
    if( fileUrl != nil ) {
        paramDict[HJCameraManagerNotifyParameterKeyFileUrl] = fileUrl;
    }
    dispatch_async( dispatch_get_main_queue(), ^{
        if( completion != nil ) {
            completion(status, image, fileUrl);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:HJCameraManagerNotification object:self userInfo:paramDict];
    });
}
    
- (AVCaptureConnection *)videoConnectionOfCaptureOutput:(AVCaptureOutput *)output
{
    if( output == nil ) {
        return nil;
    }
    AVCaptureConnection *foundConnection = nil;
    for( AVCaptureConnection *connection in output.connections ) {
        for( AVCaptureInputPort *inputPort in [connection inputPorts] ) {
            if( [[inputPort mediaType] isEqualToString:AVMediaTypeVideo] == YES ) {
                foundConnection = connection;
                break;
            }
        }
        if( foundConnection != nil ) {
            break;
        }
    }
    
    return foundConnection;
}

- (BOOL)updateVideoOrientationForCaptureOutput:(AVCaptureOutput *)output
{
    if( output == nil ) {
        return NO;
    }
    AVCaptureConnection *connection = [self videoConnectionOfCaptureOutput:output];
    if( connection == nil ) {
        return NO;
    }
    switch( self.videoOrientation ) {
        case HJCameraManagerVideoOrientationLandscapeLeft :
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case HJCameraManagerVideoOrientationLandscapeRight :
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case HJCameraManagerVideoOrientationPortraitUpsideDown :
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default :
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    return YES;
}

- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for( AVCaptureDevice *device in devices ) {
        if( device.position == position ) {
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
        image =  [UIImage imageWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationRight];
        CGImageRelease(imageRef);
    }
    return image;
}

+ (HJCameraManagerVideoOrientation)orientationFor:(CGAffineTransform)preferredTransform
{
    HJCameraManagerVideoOrientation orientation = HJCameraManagerVideoOrientationPortrait;
    if( (preferredTransform.a == 0) && (preferredTransform.b == 1) && (preferredTransform.c == -1) && (preferredTransform.d == 0) ) {
        orientation = HJCameraManagerVideoOrientationPortrait;
    } else if( (preferredTransform.a == 0) && (preferredTransform.b == -1) && (preferredTransform.c == 1) && (preferredTransform.d == 0) ) {
        orientation = HJCameraManagerVideoOrientationPortraitUpsideDown;
    } else if( (preferredTransform.a == 1) && (preferredTransform.b == 0) && (preferredTransform.c == 0) && (preferredTransform.d == 1) ) {
        orientation = HJCameraManagerVideoOrientationLandscapeRight;
    } else if( (preferredTransform.a == -1) && (preferredTransform.b == 0) && (preferredTransform.c == 0) && (preferredTransform.d == -1) ) {
        orientation = HJCameraManagerVideoOrientationLandscapeLeft;
    }
    return orientation;
}

+ (CGAffineTransform)transformFor:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform
{
    HJCameraManagerVideoOrientation orientation = [HJCameraManager orientationFor:preferredTransform];
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGFloat sx = 1;
    CGFloat sy = 1;
    switch( orientation ) {
        case HJCameraManagerVideoOrientationPortrait :
            sx = renderSize.width/naturalSize.height;
            sy = renderSize.height/naturalSize.width;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sy, sx));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(90*(M_PI/180)));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(renderSize.width, 0));
            break;
        case HJCameraManagerVideoOrientationPortraitUpsideDown :
            sx = renderSize.width/naturalSize.height;
            sy = renderSize.height/naturalSize.width;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sy, sx));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(-90*(M_PI/180)));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0, renderSize.height));
            break;
        case HJCameraManagerVideoOrientationLandscapeRight :
            sx = renderSize.width/naturalSize.width;
            sy = renderSize.height/naturalSize.height;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sx, sy));
            break;
        case HJCameraManagerVideoOrientationLandscapeLeft :
            sx = renderSize.width/naturalSize.width;
            sy = renderSize.height/naturalSize.height;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(-sx, -sy));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(renderSize.width, renderSize.height));
            break;
        default :
            break;
    }
    return transform;
}

+ (CGSize)sizeForCenterCrop:(CGSize)naturalSize
{
    if( naturalSize.width > naturalSize.height ) {
        return CGSizeMake(naturalSize.height, naturalSize.height);
    }
    return CGSizeMake(naturalSize.width, naturalSize.width);
}

+ (CGAffineTransform)transformForCenterCrop:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform
{
    if( renderSize.width > renderSize.height ) {
        renderSize.width = renderSize.height;
    }
    if( renderSize.height > renderSize.width ) {
        renderSize.height = renderSize.width;
    }
    HJCameraManagerVideoOrientation orientation = [HJCameraManager orientationFor:preferredTransform];
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGFloat s = 1, angle = 0, tx = 0, ty = 0;
    switch( orientation ) {
        case HJCameraManagerVideoOrientationPortrait :
            if( naturalSize.width > naturalSize.height ) {
                s = renderSize.height/naturalSize.height;
                tx = renderSize.width;
                ty = (naturalSize.height-naturalSize.width)*0.5*s;
            } else {
                s = renderSize.width/naturalSize.width;
                tx = (((naturalSize.height-naturalSize.width)*s)+renderSize.width)*0.5;
                ty = 0;
            }
            angle = 90;
            break;
        case HJCameraManagerVideoOrientationPortraitUpsideDown :
            if( naturalSize.width > naturalSize.height ) {
                s = renderSize.height/naturalSize.height;
                tx = 0;
                ty = (((naturalSize.width-naturalSize.height)*s)+renderSize.width)*0.5;
            } else {
                s = renderSize.width/naturalSize.width;
                tx = (naturalSize.height-naturalSize.width)*0.5*s;
                ty = renderSize.height;
            }
            angle = -90;
            break;
        case HJCameraManagerVideoOrientationLandscapeRight :
            if( naturalSize.width > naturalSize.height ) {
                s = renderSize.height/naturalSize.height;
                tx = (naturalSize.height-naturalSize.width)*0.5*s;
                ty = 0;
            } else {
                s = renderSize.width/naturalSize.width;
                tx = 0;
                ty = (naturalSize.width-naturalSize.height)*0.5*s;
            }
            break;
        case HJCameraManagerVideoOrientationLandscapeLeft :
            if( naturalSize.width > naturalSize.height ) {
                s = renderSize.height/naturalSize.height;
                tx = ((naturalSize.width-naturalSize.height)*0.5*s)+renderSize.width;
                ty = renderSize.width;
            } else {
                s = -renderSize.width/naturalSize.width;
                tx = renderSize.width;
                ty = ((naturalSize.height-naturalSize.width)*0.5*s)+renderSize.width;
            }
            s = -s;
            break;
        default :
            break;
    }
    if( s != 1 ) {
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(s, s));
    }
    if( angle != 0 ) {
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(angle*(M_PI/180)));
    }
    if( (tx != 0) || (ty != 0) ) {
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(tx, ty));
    }
    return transform;
}

+ (UIImage *)orientationFixImage:(UIImage *)image videoOrientation:(HJCameraManagerVideoOrientation)videoOrientation
{
    if( image == nil ) {
        return nil;
    }
    
    UIImage *processedImage = nil;
    
    if( image.imageOrientation != UIImageOrientationUp ) {
        UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
        [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
        processedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else {
        processedImage = image;
    }
    
    if( videoOrientation != HJCameraManagerVideoOrientationPortrait ) {
        UIImageOrientation orientation = UIImageOrientationUp;
        switch( videoOrientation ) {
            case HJCameraManagerVideoOrientationLandscapeLeft :
                orientation = UIImageOrientationLeft;
                break;
            case HJCameraManagerVideoOrientationLandscapeRight :
                orientation = UIImageOrientationRight;
                break;
            case HJCameraManagerVideoOrientationPortraitUpsideDown :
                orientation = UIImageOrientationUpMirrored;
                break;
            default :
                break;
        }
        processedImage = [[UIImage alloc] initWithCGImage: processedImage.CGImage scale: processedImage.scale orientation: orientation];
        UIGraphicsBeginImageContextWithOptions(processedImage.size, YES, processedImage.scale);
        [processedImage drawInRect:CGRectMake(0, 0, processedImage.size.width, processedImage.size.height)];
        processedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    return processedImage;
}

+ (UIImage *)processingImage:(UIImage *)image type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize
{
    if( image == nil ) {
        return nil;
    }
    
    CGSize imageSize = image.size;
    UIImage *processedImage = nil;
    CGRect canvasRect = CGRectMake(0, 0, imageSize.width, imageSize.height);
    
    switch( type ) {
        case HJCameraManagerImageProcessingTypePass :
            processedImage = image;
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenWidth :
            if( referenceSize.width <= 0.0 ) {
                return nil;
            }
            canvasRect.size.width = referenceSize.width;
            canvasRect.size.height = (CGFloat)floor((double)(imageSize.height*(referenceSize.width/imageSize.width)));
            canvasRect.origin = CGPointZero;
            UIGraphicsBeginImageContextWithOptions(canvasRect.size, YES, image.scale);
            [image drawInRect:canvasRect];
            processedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenHeight :
            if( referenceSize.height <= 0.0 ) {
                return nil;
            }
            canvasRect.size.width = (CGFloat)floor((double)(imageSize.width*(referenceSize.height/imageSize.height)));
            canvasRect.size.height = referenceSize.height;
            canvasRect.origin = CGPointZero;
            UIGraphicsBeginImageContextWithOptions(canvasRect.size, YES, image.scale);
            [image drawInRect:canvasRect];
            processedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenSize :
            if( (referenceSize.width <= 0.0) || (referenceSize.height <= 0.0) ) {
                return nil;
            }
            canvasRect.size = referenceSize;
            canvasRect.origin = CGPointZero;
            UIGraphicsBeginImageContextWithOptions(canvasRect.size, YES, image.scale);
            [image drawInRect:canvasRect];
            processedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenRate :
            if( (referenceSize.width <= 0.0) || (referenceSize.height <= 0.0) ) {
                return nil;
            } else {
                CGFloat r1 = imageSize.width/imageSize.height;
                CGFloat r2 = referenceSize.width/referenceSize.height;
                canvasRect.size.width = (CGFloat)floor((double)(imageSize.width*r1));
                canvasRect.size.height = (CGFloat)floor((double)(canvasRect.size.width/r2));
                canvasRect.origin = CGPointZero;
                UIGraphicsBeginImageContextWithOptions(canvasRect.size, YES, image.scale);
                [image drawInRect:canvasRect];
                processedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            }
            break;
        case HJCameraManagerImageProcessingTypeCropCenterSquare :
            if( imageSize.width > imageSize.height ) {
                canvasRect.size.width = imageSize.height;
                canvasRect.size.height = imageSize.height;
                canvasRect.origin.x = (CGFloat)floor((double)(imageSize.width-imageSize.height)*0.5);
                canvasRect.origin.y = 0.0;
            } else {
                canvasRect.size.width = canvasRect.size.width;
                canvasRect.size.height = canvasRect.size.width;
                canvasRect.origin.x = 0.0;
                canvasRect.origin.y = (CGFloat)floor((double)((imageSize.height-imageSize.width)*0.5));
            }
            processedImage = [HJCameraManager cropImage:image cropRect:canvasRect];
            break;
        case HJCameraManagerImageProcessingTypeCropCenterSquareAndResizeByGivenWidth :
            if( referenceSize.width <= 0.0 ) {
                return nil;
            }
            if( imageSize.width > imageSize.height ) {
                canvasRect.size.width = imageSize.height;
                canvasRect.size.height = imageSize.height;
                canvasRect.origin.x = (CGFloat)floor((double)((imageSize.width-imageSize.height)*0.5));
                canvasRect.origin.y = 0.0;
            } else {
                canvasRect.size.width = imageSize.width;
                canvasRect.size.height = imageSize.width;
                canvasRect.origin.x = 0.0;
                canvasRect.origin.y = (CGFloat)floor((double)((imageSize.height-imageSize.width)*0.5));
            }
            processedImage = [HJCameraManager cropImage:image cropRect:canvasRect];
            if( processedImage != nil ) {
                canvasRect.size.width = referenceSize.width;
                canvasRect.size.height = referenceSize.width;
                canvasRect.origin = CGPointZero;
                UIGraphicsBeginImageContextWithOptions(canvasRect.size, YES, image.scale);
                [processedImage drawInRect:canvasRect];
                processedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            }
            break;
        default :
            return nil;
    }
    
    return processedImage;
}

+ (UIImage *)cropImage:(UIImage *)image cropRect:(CGRect)cropRect
{
    if( (image == nil) || (cropRect.size.width <= 0.0) || (cropRect.size.height <= 0.0) ) {
        return nil;
    }
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (image.imageOrientation) {
        case UIImageOrientationLeft :
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(90/180.0*M_PI), 0, -image.size.height);
            break;
        case UIImageOrientationRight :
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-90/180.0*M_PI), -image.size.width, 0);
            break;
        case UIImageOrientationDown :
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-180/180.0*M_PI), -image.size.width, -image.size.height);
            break;
        default :
            break;
    };
    transform = CGAffineTransformScale(transform, image.scale, image.scale);
    UIImage *croppedImage = nil;
    CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, CGRectApplyAffineTransform(cropRect, transform));
    if( imageRef != NULL ) {
        croppedImage = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
        CGImageRelease(imageRef);
    }
    if( CGSizeEqualToSize(croppedImage.size, cropRect.size) == false ) {
        UIGraphicsBeginImageContextWithOptions(cropRect.size, YES, image.scale);
        [croppedImage drawInRect:CGRectMake(0, 0, cropRect.size.width, cropRect.size.height)];
        croppedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return croppedImage;
}

+ (AVAssetExportSession *)exportSessionForProcessingVideo:(NSURL *)fileUrl toOutputFileUrl:(NSURL *)outputFileUrl type:(HJCameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString *)preset
{
    if( (fileUrl == nil) || (outputFileUrl == nil) ) {
        return nil;
    }
    
    AVAsset *asset = [AVAsset assetWithURL:fileUrl];
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if( tracks.count < 1 ) {
        return nil;
    }
    AVAssetTrack *assetTack = tracks[0];
    AVMutableVideoCompositionInstruction *vci = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    vci.timeRange = assetTack.timeRange;
    AVMutableVideoCompositionLayerInstruction* vcli = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:assetTack];
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    CGAffineTransform transform = CGAffineTransformIdentity;

    switch( type ) {
        case HJCameraManagerImageProcessingTypePass :
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenWidth :
            if( referenceSize.width <= 0.0 ) {
                return nil;
            } else {
                CGFloat rate = referenceSize.width/assetTack.naturalSize.width;
                videoComposition.renderSize = CGSizeMake(referenceSize.width, (CGFloat)floor((double)(assetTack.naturalSize.height*rate)));
                transform = [HJCameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenHeight :
            if( referenceSize.height <= 0.0 ) {
                return nil;
            } else {
                CGFloat rate = referenceSize.height/assetTack.naturalSize.height;
                videoComposition.renderSize = CGSizeMake((CGFloat)floor((double)(referenceSize.width*rate)), referenceSize.height);
                transform = [HJCameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenSize :
            if( (referenceSize.width <= 0.0) || (referenceSize.height <= 0.0) ) {
                return nil;
            } else {
                videoComposition.renderSize = referenceSize;
                transform = [HJCameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case HJCameraManagerImageProcessingTypeResizeByGivenRate :
            if( (referenceSize.width <= 0.0) || (referenceSize.height <= 0.0) ) {
                return nil;
            } else {
                CGFloat rate1 = assetTack.naturalSize.width/assetTack.naturalSize.height;
                CGFloat rate2 = referenceSize.width/referenceSize.height;
                CGFloat renderWidth = (CGFloat)floor((double)(assetTack.naturalSize.width*rate1));
                videoComposition.renderSize = CGSizeMake(renderWidth, (CGFloat)floor((double)(renderWidth/rate2)));
                transform = [HJCameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case HJCameraManagerImageProcessingTypeCropCenterSquare :
            videoComposition.renderSize = [HJCameraManager sizeForCenterCrop:assetTack.naturalSize];
            transform = [HJCameraManager transformForCenterCrop:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            break;
        case HJCameraManagerImageProcessingTypeCropCenterSquareAndResizeByGivenWidth :
            if( referenceSize.width <= 0.0 ) {
                return nil;
            }
            videoComposition.renderSize = CGSizeMake(referenceSize.width, referenceSize.height);
            transform = [HJCameraManager transformForCenterCrop:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            break;
        default :
            return nil;
    }

    [vcli setTransform:transform atTime:kCMTimeZero];
    vci.layerInstructions = @[vcli];
    videoComposition.instructions = @[vci];

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    if( exporter == nil ) {
        return nil;
    }
    exporter.videoComposition = videoComposition;
    exporter.outputURL = outputFileUrl;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;

    return exporter;
}

- (NSInteger)countOfCamera
{
    @synchronized (self) {
        return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    }
}

- (HJCameraManagerFlashMode)flashMode
{
    @synchronized (self) {
        return _flashMode;
    }
}

- (void)setFlashMode:(HJCameraManagerFlashMode)flashMode
{
    if( _flashMode == flashMode ) {
        return;
    }
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
    
    @synchronized (self) {
        _flashMode = flashMode;
        if( _isRunning == NO ) {
            return;
        }
        AVCaptureDevice *captureDevice = [_captureDeviceInput device];
        if( ([captureDevice hasFlash] == YES) && ([captureDevice isFlashModeSupported:mode] == YES) ) {
            NSError *error = nil;
            if( [captureDevice lockForConfiguration:&error] == YES ) {
                captureDevice.flashMode = mode;
                [captureDevice unlockForConfiguration];
            }
        }
    }
}

- (HJCameraManagerTorchMode)torchMode
{
    @synchronized (self) {
        return _torchMode;
    }
}

- (void)setTorchMode:(HJCameraManagerTorchMode)torchMode
{
    if( _torchMode == torchMode ) {
        return;
    }
    AVCaptureTorchMode mode;
    switch( torchMode ) {
        case HJCameraManagerTorchModeOn :
            mode = AVCaptureTorchModeOn;
            break;
        case HJCameraManagerTorchModeOff :
            mode = AVCaptureTorchModeOff;
            break;
        case HJCameraManagerTorchModeAuto :
            mode = AVCaptureTorchModeAuto;
            break;
        default :
            return;
    }
    
    @synchronized (self) {
        _torchMode = torchMode;
        if( _isRunning == NO ) {
            return;
        }
        AVCaptureDevice *captureDevice = [_captureDeviceInput device];
        if( ([captureDevice hasTorch] == YES) && ([captureDevice isTorchModeSupported:mode] == YES) ) {
            NSError *error = nil;
            if( [captureDevice lockForConfiguration:&error] == YES ) {
                [captureDevice setTorchMode:mode];
                [captureDevice unlockForConfiguration];
            }
        }
    }
}

- (HJCameraManagerDevicePosition)devicePosition
{
    @synchronized (self) {
        return _devicePosition;
    }
}

- (void)setDevicePosition:(HJCameraManagerDevicePosition)devicePosition
{
    if( _devicePosition == devicePosition ) {
        return;
    }
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
    @synchronized (self) {
        _devicePosition = devicePosition;
        if( _isRunning == NO ) {
            return;
        }
        if( [[_captureDeviceInput device] position] != position ) {
            AVCaptureDevice *captureDevice;
            if( (captureDevice = [self captureDeviceForPosition:position]) != nil ) {
                AVCaptureDeviceInput *captureDeviceInput;
                NSError *error = nil;
                if( (captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error]) != nil ) {
                    [_session beginConfiguration];
                    [_session removeInput:_captureDeviceInput];
                    if( [_session canAddInput:captureDeviceInput] == NO ) {
                        [_session addInput:_captureDeviceInput];
                    } else {
                        _captureDeviceInput = captureDeviceInput;
                        [_session addInput:_captureDeviceInput];
                    }
                    [_session commitConfiguration];
                }
            }
        }
    }
}

- (HJCameraManagerVideoOrientation)videoOrientation
{
    @synchronized (self) {
        return _videoOrientation;
    }
}

- (void)setVideoOrientation:(HJCameraManagerVideoOrientation)videoOrientation
{
    if( _videoOrientation == videoOrientation ) {
        return;
    }
    AVCaptureVideoOrientation orientation;
    switch( videoOrientation ) {
        case HJCameraManagerVideoOrientationPortrait :
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case HJCameraManagerVideoOrientationPortraitUpsideDown :
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case HJCameraManagerVideoOrientationLandscapeLeft :
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case HJCameraManagerVideoOrientationLandscapeRight :
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default :
            return;
    }
    @synchronized (self) {
        _videoOrientation = videoOrientation;
        if( _isRunning == NO ) {
            return;
        }
        if( _videoPreviewLayer.connection.isVideoOrientationSupported == YES ) {
            _videoPreviewLayer.connection.videoOrientation = orientation;
            _videoPreviewLayer.bounds = _videoPreviewLayer.bounds;
        }
    }
}

- (HJCameraManagerPreviewContentMode)previewContentMode
{
    @synchronized (self) {
        return _previewContentMode;
    }
}
    
- (void)setPreviewContentMode:(HJCameraManagerPreviewContentMode)previewContentMode
{
    if( _previewContentMode == previewContentMode ) {
        return;
    }
    AVLayerVideoGravity videoGravity;
    switch( previewContentMode ) {
        case HJCameraManagerPreviewContentModeResizeAspect :
            videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case HJCameraManagerPreviewContentModeResizeAspectFill :
            videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        case HJCameraManagerPreviewContentModeResize :
            videoGravity = AVLayerVideoGravityResize;
            break;
        default :
            return;
    }
    
    @synchronized (self) {
        _previewContentMode = previewContentMode;
        _videoPreviewLayer.videoGravity = videoGravity;
    }
}

- (BOOL)isVideoRecording
{
    if( (_isRunning == NO) || ([_movieFileOutput connectionWithMediaType:AVMediaTypeVideo].active == NO) ) {
        return NO;
    }
    
    return _movieFileOutput.isRecording;
}

// MARK: — AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    BOOL notify = _notifyPreviewImage;
    NSArray *pair = nil;
    
    @synchronized (self) {
        if( _capturePreviewCompletionQueue.count > 0 ) {
            pair = [_capturePreviewCompletionQueue firstObject];
            [_capturePreviewCompletionQueue removeObjectAtIndex:0];
        }
    }
    
    if( (notify == YES) || (pair != nil) ) {
        HJCameraManagerVideoOrientation orientation = HJCameraManagerVideoOrientationPortrait;
        if( pair.count > 0 ) {
            orientation = (HJCameraManagerVideoOrientation)[pair[0] integerValue];
            switch( orientation ) {
                case HJCameraManagerVideoOrientationLandscapeLeft :
                    orientation = HJCameraManagerVideoOrientationLandscapeRight;
                    break;
                case HJCameraManagerVideoOrientationLandscapeRight :
                    orientation = HJCameraManagerVideoOrientationLandscapeLeft;
                    break;
                default :
                    break;
            }
        }
        HJCameraManagerCompletion completion = nil;
        if( pair.count > 1 ) {
            completion = (HJCameraManagerCompletion)pair[1];
        }
        UIImage *image = nil;
        if( sampleBuffer != NULL ) {
            image = [HJCameraManager orientationFixImage:[self imageFromSampleBuffer:sampleBuffer] videoOrientation:orientation];
        }
        if( (image != nil) && (notify == YES) ) {
            [self postNotifyWithStatus:HJCameraManagerStatusPreviewImageCaptured image:image fileUrl:nil completion:nil];
        }
        [self postNotifyWithStatus:(image != nil ? HJCameraManagerStatusStillImageCaptured : HJCameraManagerStatusStillImageCaptureFailed) image:image fileUrl:nil completion:completion];
    }
}

//// MARK: — AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhotoSampleBuffer:(nullable CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error
{
    @synchronized (self) {
        HJCameraManagerCompletion completion = nil;
        if( _photoCaptureCompletionQueue.count > 0 ) {
            completion = [_photoCaptureCompletionQueue firstObject];
            [_photoCaptureCompletionQueue removeObjectAtIndex:0];
        }
        if( photoSampleBuffer == NULL ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
            return;
        }
        UIImage *image = nil;
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photoSampleBuffer];
        if( data != nil ) {
            image = [[UIImage alloc] initWithData:data];
        }
        if( image != nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:image fileUrl:nil completion:completion];
        } else {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
        }
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(nullable NSError *)error API_AVAILABLE(ios(11.0))
{
    @synchronized (self) {
        HJCameraManagerCompletion completion = nil;
        if( _photoCaptureCompletionQueue.count > 0 ) {
            completion = [_photoCaptureCompletionQueue firstObject];
            [_photoCaptureCompletionQueue removeObjectAtIndex:0];
        }
        if( photo == nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
            return;
        }
        UIImage *image = nil;
        NSData *data = photo.fileDataRepresentation;
        if( data != nil ) {
            image = [[UIImage alloc] initWithData:data];
        }
        if( image != nil ) {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptured image:image fileUrl:nil completion:completion];
        } else {
            [self postNotifyWithStatus:HJCameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
        }
    }
}

// MARK: — AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections
{
    [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordBegan image:nil fileUrl:fileURL completion:nil];
}

- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error
{
    if( (error != nil) || (outputFileURL == nil) ) {
        [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordFailed image:nil fileUrl:outputFileURL completion:nil];
        return;
    }
    @synchronized (self) {
        HJCameraManagerCompletion completion = nil;
        if( _moveFileSaveToPhotosAlbumCompletionQueue.count > 0 ) {
            completion = [_moveFileSaveToPhotosAlbumCompletionQueue firstObject];
            [_moveFileSaveToPhotosAlbumCompletionQueue removeObjectAtIndex:0];
        }
        [self postNotifyWithStatus:HJCameraManagerStatusVideoRecordEnded image:nil fileUrl:outputFileURL completion:completion];
    }
}

@end
