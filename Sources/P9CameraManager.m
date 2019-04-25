//
//  P9CameraManager.m
//
//
//  Created by Tae Hyun Na on 2013. 11. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "P9CameraManager.h"

@interface P9CameraManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate>
{
    P9CameraManagerFlashMode            _flashMode;
    P9CameraManagerTorchMode            _torchMode;
    P9CameraManagerDevicePosition       _devicePosition;
    P9CameraManagerVideoOrientation     _videoOrientation;
    P9CameraManagerPreviewContentMode   _previewContentMode;
    P9CameraManagerPreviewHandler       _previewHanlder;
}

@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput API_AVAILABLE(ios(10));
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, strong) dispatch_queue_t videoOutputSerialQueue;
@property (nonatomic, strong) NSMutableArray *capturePreviewCompletionQueue;
@property (nonatomic, strong) NSMutableArray *moveFileSaveToPhotosAlbumCompletionQueue;
@property (nonatomic, strong) NSMutableArray *photoCaptureCompletionQueue;

- (void)reset;
- (void)postNotifyWithStatus:(P9CameraManagerStatus)status image:(UIImage *)image fileUrl:(NSURL *)fileUrl completion:(P9CameraManagerCompletion)completion;
- (AVCaptureConnection *)videoConnectionOfCaptureOutput:(AVCaptureOutput *)output;
- (BOOL)updateVideoOrientationForCaptureOutput:(AVCaptureOutput *)output;
- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
+ (P9CameraManagerVideoOrientation)orientationFor:(CGAffineTransform)preferredTransform;
+ (CGAffineTransform)transformFor:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform;
+ (CGSize)sizeForCenterCrop:(CGSize)naturalSize;
+ (CGAffineTransform)transformForCenterCrop:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform;
+ (dispatch_queue_t)imageProcessQueue;
+ (UIImage *)orientationFixImage:(UIImage *)image videoOrientation:(P9CameraManagerVideoOrientation)videoOrientation;
+ (UIImage *)processingImage:(UIImage *)image type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize;
+ (UIImage *)cropImage:(UIImage *)image cropRect:(CGRect)cropRect;
+ (AVAssetExportSession *)exportSessionForProcessingVideo:(NSURL *)fileUrl toOutputFileUrl:(NSURL *)outputFileUrl type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString *)preset;

@end

@implementation P9CameraManager

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
        _flashMode = P9CameraManagerFlashModeOff;
        _torchMode = P9CameraManagerTorchModeOff;
        _devicePosition = P9CameraManagerDevicePositionBack;
        _videoOrientation = P9CameraManagerVideoOrientationPortrait;
        _previewContentMode = P9CameraManagerPreviewContentModeResizeAspect;
        _notifyPreviewType = P9CameraManagerNotifyPreviewTypeNone;
        _videoOutputSerialQueue = dispatch_queue_create("p9soft.manager.p9camera-videoOutput", DISPATCH_QUEUE_SERIAL);
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

+ (P9CameraManager *)sharedManager
{
    static dispatch_once_t once;
    static P9CameraManager *sharedInstance;
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
        [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithInternalError image:nil fileUrl:nil completion:nil];
        return NO;
    }
    
    AVCaptureFlashMode flashMode = AVCaptureFlashModeOff;
    switch( _flashMode ) {
        case P9CameraManagerFlashModeOn :
            flashMode = AVCaptureFlashModeOn;
            break;
        case P9CameraManagerFlashModeOff :
            flashMode = AVCaptureFlashModeOff;
            break;
        default :
            break;
    }
    
    AVCaptureTorchMode torchMode = AVCaptureTorchModeOff;
    switch( _torchMode ) {
        case P9CameraManagerTorchModeOn :
            torchMode = AVCaptureTorchModeOn;
            break;
        case P9CameraManagerTorchModeOff :
            torchMode = AVCaptureTorchModeOff;
            break;
        default :
            break;
    }
    
    AVCaptureDevicePosition position = AVCaptureDevicePositionUnspecified;
    switch( _devicePosition ) {
        case P9CameraManagerDevicePositionBack :
            position = AVCaptureDevicePositionBack;
            break;
        case P9CameraManagerDevicePositionFront :
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
            [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithInternalError image:nil fileUrl:nil completion:nil];
            return NO;
        }
        
        [_session beginConfiguration];
        
        if( [self.session canSetSessionPreset:preset] == NO ) {
            [self reset];
            [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
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
            [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
            return NO;
        }
        [_session addInput:_captureDeviceInput];
        
        if (@available(iOS 10.0, *)) {
            _photoOutput = [[AVCapturePhotoOutput alloc] init];
            if( (_photoOutput == nil) || ([_session canAddOutput:_photoOutput] == NO) ) {
                [self reset];
                [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addOutput:_photoOutput];
        } else {
            if( (_stillImageOutput = [[AVCaptureStillImageOutput alloc] init]) == nil ) {
                [self reset];
                [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_stillImageOutput setOutputSettings:@{AVVideoCodecJPEG:AVVideoCodecKey}];
            if( [_session canAddOutput:_stillImageOutput] == NO ) {
                [self reset];
                [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
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
                [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addOutput:_movieFileOutput];
        }
        
        if( enableAudio == YES ) {
            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            if( (audioDevice == nil) || ((_audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil]) == nil) || ([_session canAddInput:_audioDeviceInput] == NO) ) {
                [self reset];
                [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithAccessDenied image:nil fileUrl:nil completion:nil];
                return NO;
            }
            [_session addInput:_audioDeviceInput];
        }
        
        [_session commitConfiguration];
        
        if( (_videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session]) == nil ) {
            [self reset];
            [self postNotifyWithStatus:P9CameraManagerStatusStartFailedWithInternalError image:nil fileUrl:nil completion:nil];
            return NO;
        }
        
        AVLayerVideoGravity gravity = AVLayerVideoGravityResizeAspect;
        switch( _previewContentMode ) {
            case P9CameraManagerPreviewContentModeResizeAspectFill :
                gravity = AVLayerVideoGravityResizeAspectFill;
                break;
            case P9CameraManagerPreviewContentModeResize :
                gravity = AVLayerVideoGravityResize;
                break;
            default :
                break;
        }
        _videoPreviewLayer.videoGravity = gravity;
        if( _videoPreviewLayer.connection.isVideoOrientationSupported == YES ) {
            AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
            switch( _videoOrientation ) {
                case P9CameraManagerVideoOrientationPortraitUpsideDown :
                    orientation = AVCaptureVideoOrientationPortraitUpsideDown;
                    break;
                case P9CameraManagerVideoOrientationLandscapeLeft :
                    orientation = AVCaptureVideoOrientationLandscapeLeft;
                    break;
                case P9CameraManagerVideoOrientationLandscapeRight :
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
    
    [self postNotifyWithStatus:P9CameraManagerStatusRunning image:nil fileUrl:nil completion:nil];
    
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
    [self postNotifyWithStatus: P9CameraManagerStatusIdle image:nil fileUrl:nil completion:nil];
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

- (void)captureStillImage:(P9CameraManagerCompletion _Nullable)completion
{
    @synchronized (self) {
        if (@available(iOS 10.0, *)) {
            if( (_isRunning == NO) || (_photoOutput == nil) ) {
                [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
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
                [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptured image:nil fileUrl:nil completion:completion];
                return;
            }
            [_photoOutput capturePhotoWithSettings:settings delegate:self];
        } else {
            if( (_isRunning == NO) || (_stillImageOutput == nil) ) {
                [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                return;
            }
            AVCaptureConnection *connection = [self videoConnectionOfCaptureOutput:_stillImageOutput];
            if( (connection == nil) || ([self updateVideoOrientationForCaptureOutput:_stillImageOutput] == NO) ) {
                [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptured image:nil fileUrl:nil completion:completion];
                return;
            }
            [_stillImageOutput captureStillImageAsynchronouslyFromConnection: connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                if( imageDataSampleBuffer == NULL ) {
                    [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                    return;
                }
                UIImage *image = nil;
                NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                if( data != nil ) {
                    image = [[UIImage alloc] initWithData:data];
                }
                if( image != nil ) {
                    [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptured image:image fileUrl:nil completion:completion];
                } else {
                    [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
                }
            }];
        }
    }
}

- (void)capturePreviewImage:(P9CameraManagerCompletion _Nullable)completion
{
    @synchronized (self) {
        if( (_isRunning == NO) || (_videoOutput == nil) ) {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
            return;
        }
        [_capturePreviewCompletionQueue addObject:(completion != nil ? @[@(self.videoOrientation), completion] : @[@(self.videoOrientation)])];
    }
}

- (BOOL)recordVideoToFileUrl:(NSURL * _Nullable)fileUrl
{
    if( fileUrl == nil ) {
        [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordFailed image:nil fileUrl:nil completion:nil];
        return NO;
    }
    
    @synchronized (self) {
        if( (_isRunning == NO) || ([_movieFileOutput connectionWithMediaType:AVMediaTypeVideo].active == NO) || (_movieFileOutput.isRecording == YES) ) {
            [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordFailed image:nil fileUrl:fileUrl completion:nil];
            return NO;
        }
        if( [self updateVideoOrientationForCaptureOutput:_movieFileOutput] == NO ) {
            [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordFailed image:nil fileUrl:fileUrl completion:nil];
            return NO;
        }
        [_movieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    
    return YES;
}

- (void)stopRecordingVideo:(P9CameraManagerCompletion _Nullable)completion
{
    @synchronized (self) {
        if( (_isRunning == NO) || (_movieFileOutput.isRecording == NO) ) {
            [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordFailed image:nil fileUrl:_movieFileOutput.outputFileURL completion:completion];
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
            self.videoOrientation = P9CameraManagerVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown :
            self.videoOrientation = P9CameraManagerVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft :
            self.videoOrientation = P9CameraManagerVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight :
            self.videoOrientation = P9CameraManagerVideoOrientationLandscapeLeft;
            break;
        default :
            break;
    }
}

- (void)setPreviewHandler:(P9CameraManagerPreviewHandler)previewHandler
{
    @synchronized (self) {
        _previewHanlder = previewHandler;
    }
}

+ (dispatch_queue_t)imageProcessQueue
{
    static dispatch_once_t once;
    static dispatch_queue_t imageProcessSerialQueue;
    dispatch_once(&once, ^{imageProcessSerialQueue = dispatch_queue_create("p9soft.manager.p9camera-imageProcess", DISPATCH_QUEUE_SERIAL);});
    return imageProcessSerialQueue;
}

+ (void)processingImage:(UIImage * _Nullable)image type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize completion:(P9CameraManagerCompletion _Nullable)completion
{
    if( completion == nil ) {
        return;
    }
    if( image == nil ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(P9CameraManagerStatusMediaProcessingFailed, nil, nil);
        });
        return;
    }
    dispatch_async([P9CameraManager imageProcessQueue], ^{
        UIImage *processedImage = [self processingImage:image type:type referenceSize:referenceSize ];
        P9CameraManagerStatus status = (processedImage != nil ? P9CameraManagerStatusMediaProcessingDone : P9CameraManagerStatusMediaProcessingFailed);
        NSMutableDictionary *paramDict = [NSMutableDictionary new];
        paramDict[P9CameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
        if( processedImage != nil ) {
            paramDict[P9CameraManagerNotifyParameterKeyImage] = processedImage;
        }
        dispatch_async( dispatch_get_main_queue(), ^{
            if( completion != nil ) {
                completion(status, processedImage, nil);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:P9CameraManagerNotification object:self userInfo:paramDict];
        });
    });
}

+ (void)processingVideo:(NSURL * _Nullable)fileUrl toOutputFileUrl:(NSURL * _Nullable)outputFileUrl type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString *)preset completion:(P9CameraManagerCompletion _Nullable)completion
{
    if( (fileUrl == nil) || (outputFileUrl == nil) || (preset == nil) ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(P9CameraManagerStatusMediaProcessingFailed, nil, outputFileUrl);
            });
        }
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVAssetExportSession *exportSession = nil;
        NSMutableDictionary *paramDict = [NSMutableDictionary new];
        P9CameraManagerStatus status = P9CameraManagerStatusMediaProcessingFailed;
        if( type == P9CameraManagerImageProcessingTypePass ) {
            if( [NSFileManager.defaultManager copyItemAtURL:fileUrl toURL:outputFileUrl error:nil] == YES ) {
                status = P9CameraManagerStatusMediaProcessingDone;
            }
        } else {
            if( (exportSession = [self exportSessionForProcessingVideo:fileUrl toOutputFileUrl:outputFileUrl type:type referenceSize:referenceSize preset:preset]) != nil ) {
                status = P9CameraManagerStatusMediaProcessingDone;
            }
        }
        paramDict[P9CameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
        paramDict[P9CameraManagerNotifyParameterKeyFileUrl] = outputFileUrl;
        if( exportSession != nil ) {
            [[NSFileManager defaultManager] removeItemAtURL:outputFileUrl error:nil];
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if( completion != nil ) {
                        completion(status, nil, outputFileUrl);
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:P9CameraManagerNotification object:self userInfo:paramDict];
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if( completion != nil ) {
                    completion(status, nil, outputFileUrl);
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:P9CameraManagerNotification object:self userInfo:paramDict];
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

- (void)postNotifyWithStatus:(P9CameraManagerStatus)status image:(UIImage *)image fileUrl:(NSURL *)fileUrl completion:(P9CameraManagerCompletion)completion
{
    NSMutableDictionary *paramDict = [NSMutableDictionary new];
    paramDict[P9CameraManagerNotifyParameterKeyStatus] = @((NSInteger)status);
    if( image != nil ) {
        paramDict[P9CameraManagerNotifyParameterKeyImage] = image;
    }
    if( fileUrl != nil ) {
        paramDict[P9CameraManagerNotifyParameterKeyFileUrl] = fileUrl;
    }
    dispatch_async( dispatch_get_main_queue(), ^{
        if( completion != nil ) {
            completion(status, image, fileUrl);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:P9CameraManagerNotification object:self userInfo:paramDict];
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
        case P9CameraManagerVideoOrientationLandscapeLeft :
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case P9CameraManagerVideoOrientationLandscapeRight :
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case P9CameraManagerVideoOrientationPortraitUpsideDown :
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

+ (P9CameraManagerVideoOrientation)orientationFor:(CGAffineTransform)preferredTransform
{
    P9CameraManagerVideoOrientation orientation = P9CameraManagerVideoOrientationPortrait;
    if( (preferredTransform.a == 0) && (preferredTransform.b == 1) && (preferredTransform.c == -1) && (preferredTransform.d == 0) ) {
        orientation = P9CameraManagerVideoOrientationPortrait;
    } else if( (preferredTransform.a == 0) && (preferredTransform.b == -1) && (preferredTransform.c == 1) && (preferredTransform.d == 0) ) {
        orientation = P9CameraManagerVideoOrientationPortraitUpsideDown;
    } else if( (preferredTransform.a == 1) && (preferredTransform.b == 0) && (preferredTransform.c == 0) && (preferredTransform.d == 1) ) {
        orientation = P9CameraManagerVideoOrientationLandscapeRight;
    } else if( (preferredTransform.a == -1) && (preferredTransform.b == 0) && (preferredTransform.c == 0) && (preferredTransform.d == -1) ) {
        orientation = P9CameraManagerVideoOrientationLandscapeLeft;
    }
    return orientation;
}

+ (CGAffineTransform)transformFor:(CGSize)renderSize naturalSize:(CGSize)naturalSize preferredTransform:(CGAffineTransform)preferredTransform
{
    P9CameraManagerVideoOrientation orientation = [P9CameraManager orientationFor:preferredTransform];
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGFloat sx = 1;
    CGFloat sy = 1;
    switch( orientation ) {
        case P9CameraManagerVideoOrientationPortrait :
            sx = renderSize.width/naturalSize.height;
            sy = renderSize.height/naturalSize.width;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sy, sx));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(90*(M_PI/180)));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(renderSize.width, 0));
            break;
        case P9CameraManagerVideoOrientationPortraitUpsideDown :
            sx = renderSize.width/naturalSize.height;
            sy = renderSize.height/naturalSize.width;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sy, sx));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(-90*(M_PI/180)));
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0, renderSize.height));
            break;
        case P9CameraManagerVideoOrientationLandscapeRight :
            sx = renderSize.width/naturalSize.width;
            sy = renderSize.height/naturalSize.height;
            transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sx, sy));
            break;
        case P9CameraManagerVideoOrientationLandscapeLeft :
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
    P9CameraManagerVideoOrientation orientation = [P9CameraManager orientationFor:preferredTransform];
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGFloat s = 1, angle = 0, tx = 0, ty = 0;
    switch( orientation ) {
        case P9CameraManagerVideoOrientationPortrait :
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
        case P9CameraManagerVideoOrientationPortraitUpsideDown :
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
        case P9CameraManagerVideoOrientationLandscapeRight :
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
        case P9CameraManagerVideoOrientationLandscapeLeft :
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

+ (UIImage *)orientationFixImage:(UIImage *)image videoOrientation:(P9CameraManagerVideoOrientation)videoOrientation
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
    
    if( videoOrientation != P9CameraManagerVideoOrientationPortrait ) {
        UIImageOrientation orientation = UIImageOrientationUp;
        switch( videoOrientation ) {
            case P9CameraManagerVideoOrientationLandscapeLeft :
                orientation = UIImageOrientationLeft;
                break;
            case P9CameraManagerVideoOrientationLandscapeRight :
                orientation = UIImageOrientationRight;
                break;
            case P9CameraManagerVideoOrientationPortraitUpsideDown :
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

+ (UIImage *)processingImage:(UIImage *)image type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize
{
    if( image == nil ) {
        return nil;
    }
    
    CGSize imageSize = image.size;
    UIImage *processedImage = nil;
    CGRect canvasRect = CGRectMake(0, 0, imageSize.width, imageSize.height);
    
    switch( type ) {
        case P9CameraManagerImageProcessingTypePass :
            processedImage = image;
            break;
        case P9CameraManagerImageProcessingTypeResizeByGivenWidth :
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
        case P9CameraManagerImageProcessingTypeResizeByGivenHeight :
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
        case P9CameraManagerImageProcessingTypeResizeByGivenSize :
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
        case P9CameraManagerImageProcessingTypeResizeByGivenRate :
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
        case P9CameraManagerImageProcessingTypeCropCenterSquare :
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
            processedImage = [P9CameraManager cropImage:image cropRect:canvasRect];
            break;
        case P9CameraManagerImageProcessingTypeCropCenterSquareAndResizeByGivenWidth :
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
            processedImage = [P9CameraManager cropImage:image cropRect:canvasRect];
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

+ (AVAssetExportSession *)exportSessionForProcessingVideo:(NSURL *)fileUrl toOutputFileUrl:(NSURL *)outputFileUrl type:(P9CameraManagerImageProcessingType)type referenceSize:(CGSize)referenceSize preset:(NSString *)preset
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
        case P9CameraManagerImageProcessingTypePass :
            break;
        case P9CameraManagerImageProcessingTypeResizeByGivenWidth :
            if( referenceSize.width <= 0.0 ) {
                return nil;
            } else {
                CGFloat rate = referenceSize.width/assetTack.naturalSize.width;
                videoComposition.renderSize = CGSizeMake(referenceSize.width, (CGFloat)floor((double)(assetTack.naturalSize.height*rate)));
                transform = [P9CameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case P9CameraManagerImageProcessingTypeResizeByGivenHeight :
            if( referenceSize.height <= 0.0 ) {
                return nil;
            } else {
                CGFloat rate = referenceSize.height/assetTack.naturalSize.height;
                videoComposition.renderSize = CGSizeMake((CGFloat)floor((double)(referenceSize.width*rate)), referenceSize.height);
                transform = [P9CameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case P9CameraManagerImageProcessingTypeResizeByGivenSize :
            if( (referenceSize.width <= 0.0) || (referenceSize.height <= 0.0) ) {
                return nil;
            } else {
                videoComposition.renderSize = referenceSize;
                transform = [P9CameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case P9CameraManagerImageProcessingTypeResizeByGivenRate :
            if( (referenceSize.width <= 0.0) || (referenceSize.height <= 0.0) ) {
                return nil;
            } else {
                CGFloat rate1 = assetTack.naturalSize.width/assetTack.naturalSize.height;
                CGFloat rate2 = referenceSize.width/referenceSize.height;
                CGFloat renderWidth = (CGFloat)floor((double)(assetTack.naturalSize.width*rate1));
                videoComposition.renderSize = CGSizeMake(renderWidth, (CGFloat)floor((double)(renderWidth/rate2)));
                transform = [P9CameraManager transformFor:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            }
            break;
        case P9CameraManagerImageProcessingTypeCropCenterSquare :
            videoComposition.renderSize = [P9CameraManager sizeForCenterCrop:assetTack.naturalSize];
            transform = [P9CameraManager transformForCenterCrop:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
            break;
        case P9CameraManagerImageProcessingTypeCropCenterSquareAndResizeByGivenWidth :
            if( referenceSize.width <= 0.0 ) {
                return nil;
            }
            videoComposition.renderSize = CGSizeMake(referenceSize.width, referenceSize.height);
            transform = [P9CameraManager transformForCenterCrop:videoComposition.renderSize naturalSize:assetTack.naturalSize preferredTransform:assetTack.preferredTransform];
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

- (P9CameraManagerFlashMode)flashMode
{
    @synchronized (self) {
        return _flashMode;
    }
}

- (void)setFlashMode:(P9CameraManagerFlashMode)flashMode
{
    if( _flashMode == flashMode ) {
        return;
    }
    AVCaptureFlashMode mode;
    switch( flashMode ) {
        case P9CameraManagerFlashModeOn :
            mode = AVCaptureFlashModeOn;
            break;
        case P9CameraManagerFlashModeOff :
            mode = AVCaptureFlashModeOff;
            break;
        case P9CameraManagerFlashModeAuto :
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

- (P9CameraManagerTorchMode)torchMode
{
    @synchronized (self) {
        return _torchMode;
    }
}

- (void)setTorchMode:(P9CameraManagerTorchMode)torchMode
{
    if( _torchMode == torchMode ) {
        return;
    }
    AVCaptureTorchMode mode;
    switch( torchMode ) {
        case P9CameraManagerTorchModeOn :
            mode = AVCaptureTorchModeOn;
            break;
        case P9CameraManagerTorchModeOff :
            mode = AVCaptureTorchModeOff;
            break;
        case P9CameraManagerTorchModeAuto :
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

- (P9CameraManagerDevicePosition)devicePosition
{
    @synchronized (self) {
        return _devicePosition;
    }
}

- (void)setDevicePosition:(P9CameraManagerDevicePosition)devicePosition
{
    if( _devicePosition == devicePosition ) {
        return;
    }
    AVCaptureDevicePosition position;
    switch( devicePosition ) {
        case P9CameraManagerDevicePositionBack :
            position = AVCaptureDevicePositionBack;
            break;
        case P9CameraManagerDevicePositionFront :
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

- (P9CameraManagerVideoOrientation)videoOrientation
{
    @synchronized (self) {
        return _videoOrientation;
    }
}

- (void)setVideoOrientation:(P9CameraManagerVideoOrientation)videoOrientation
{
    if( _videoOrientation == videoOrientation ) {
        return;
    }
    AVCaptureVideoOrientation orientation;
    switch( videoOrientation ) {
        case P9CameraManagerVideoOrientationPortrait :
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case P9CameraManagerVideoOrientationPortraitUpsideDown :
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case P9CameraManagerVideoOrientationLandscapeLeft :
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case P9CameraManagerVideoOrientationLandscapeRight :
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

- (P9CameraManagerPreviewContentMode)previewContentMode
{
    @synchronized (self) {
        return _previewContentMode;
    }
}
    
- (void)setPreviewContentMode:(P9CameraManagerPreviewContentMode)previewContentMode
{
    if( _previewContentMode == previewContentMode ) {
        return;
    }
    AVLayerVideoGravity videoGravity;
    switch( previewContentMode ) {
        case P9CameraManagerPreviewContentModeResizeAspect :
            videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case P9CameraManagerPreviewContentModeResizeAspectFill :
            videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        case P9CameraManagerPreviewContentModeResize :
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
    NSArray *pair = nil;
    P9CameraManagerNotifyPreviewType notifyPreviewType = P9CameraManagerNotifyPreviewTypeNone;
    
    @synchronized (self) {
        if( _capturePreviewCompletionQueue.count > 0 ) {
            pair = [_capturePreviewCompletionQueue firstObject];
            [_capturePreviewCompletionQueue removeObjectAtIndex:0];
        }
        notifyPreviewType = _notifyPreviewType;
        if( _previewHanlder != nil ) {
            _previewHanlder(sampleBuffer);
        }
    }
    
    if( (notifyPreviewType == P9CameraManagerNotifyPreviewTypeNone) && (pair.count == 0) ) {
        return;
    }
    
    P9CameraManagerVideoOrientation orientation = P9CameraManagerVideoOrientationPortrait;
    if( pair.count > 0 ) {
        orientation = (P9CameraManagerVideoOrientation)[pair[0] integerValue];
        switch( orientation ) {
            case P9CameraManagerVideoOrientationLandscapeLeft :
                orientation = P9CameraManagerVideoOrientationLandscapeRight;
                break;
            case P9CameraManagerVideoOrientationLandscapeRight :
                orientation = P9CameraManagerVideoOrientationLandscapeLeft;
                break;
            default :
                break;
        }
    }
    UIImage *image = nil;
    if( (sampleBuffer != NULL) && ((notifyPreviewType == P9CameraManagerNotifyPreviewTypeImage) || (pair != nil)) ) {
        image = [P9CameraManager orientationFixImage:[self imageFromSampleBuffer:sampleBuffer] videoOrientation:orientation];
    }
    if( pair != nil ) {
        P9CameraManagerCompletion completion = (pair.count > 1 ? (P9CameraManagerCompletion)pair[1] : nil);
        [self postNotifyWithStatus:(image != nil ? P9CameraManagerStatusStillImageCaptured : P9CameraManagerStatusStillImageCaptureFailed) image:image fileUrl:nil completion:completion];
    }
    switch( notifyPreviewType ) {
        case P9CameraManagerNotifyPreviewTypeImage :
            if( image != nil ) {
                [self postNotifyWithStatus:P9CameraManagerStatusPreviewImageCaptured image:image fileUrl:nil completion:nil];
            }
            break;
        default :
            break;
    }
}

//// MARK: — AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhotoSampleBuffer:(nullable CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error API_AVAILABLE(ios(10))
{
    @synchronized (self) {
        P9CameraManagerCompletion completion = nil;
        if( _photoCaptureCompletionQueue.count > 0 ) {
            completion = [_photoCaptureCompletionQueue firstObject];
            [_photoCaptureCompletionQueue removeObjectAtIndex:0];
        }
        if( photoSampleBuffer == NULL ) {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
            return;
        }
        UIImage *image = nil;
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photoSampleBuffer];
        if( data != nil ) {
            image = [[UIImage alloc] initWithData:data];
        }
        if( image != nil ) {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptured image:image fileUrl:nil completion:completion];
        } else {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
        }
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(nullable NSError *)error API_AVAILABLE(ios(11.0))
{
    @synchronized (self) {
        P9CameraManagerCompletion completion = nil;
        if( _photoCaptureCompletionQueue.count > 0 ) {
            completion = [_photoCaptureCompletionQueue firstObject];
            [_photoCaptureCompletionQueue removeObjectAtIndex:0];
        }
        if( photo == nil ) {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
            return;
        }
        UIImage *image = nil;
        NSData *data = photo.fileDataRepresentation;
        if( data != nil ) {
            image = [[UIImage alloc] initWithData:data];
        }
        if( image != nil ) {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptured image:image fileUrl:nil completion:completion];
        } else {
            [self postNotifyWithStatus:P9CameraManagerStatusStillImageCaptureFailed image:nil fileUrl:nil completion:completion];
        }
    }
}

// MARK: — AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections
{
    [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordBegan image:nil fileUrl:fileURL completion:nil];
}

- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error
{
    if( (error != nil) || (outputFileURL == nil) ) {
        [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordFailed image:nil fileUrl:outputFileURL completion:nil];
        return;
    }
    @synchronized (self) {
        P9CameraManagerCompletion completion = nil;
        if( _moveFileSaveToPhotosAlbumCompletionQueue.count > 0 ) {
            completion = [_moveFileSaveToPhotosAlbumCompletionQueue firstObject];
            [_moveFileSaveToPhotosAlbumCompletionQueue removeObjectAtIndex:0];
        }
        [self postNotifyWithStatus:P9CameraManagerStatusVideoRecordEnded image:nil fileUrl:outputFileURL completion:completion];
    }
}

@end
