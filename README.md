HJCameraManager
============

Easy, and quick library for handling iOS camera.

# Installation

You can download the latest framework files from our Release page.
HJCameraManager also available through CocoaPods. To install it simply add the following line to your Podfile.
pod ‘HJCameraManager’

# Play

You can choose starting mode to capture photo or video.

Start preview to taking photo like this,

```swift
HJCameraManager.shared().startWithPreviewView(forPhoto: cameraView)
```

and, video.

```swift
HJCameraManager.shared().startWithPreviewView(forVideo: cameraView, enableAudio: false)
```

or, choose start for custom setting and preset you want.

```swift
HJCameraManager.shared().start(withPreviewView: cameraView, preset: AVCaptureSessionPreset3840x2160, enableVideo: true, enableAudio: false)
```

Now, Take a picture.

```swift
HJCameraManager.shared().captureStillImage { (status:HJCameraManagerStatus, image:UIImage?, fileUrl:URL?) in
    if let image = image {
        // do something you want.
    }
}
```

Another way to take a picture. It provide smaller image then captureStillImage but no shutter sound.

```swift
HJCameraManager.shared().capturePreviewImage { (status:HJCameraManagerStatus, image:UIImage?, fileUrl:URL?) in
    if let image = image {
        // do something you want.
    }
}
```

And, recoding video like this.

```swift
HJCameraManager.shared().recordVideo(toFileUrl: url)
```

Stop recording.

```swift
HJCameraManager.shared().stopRecordingVideo({ (status, image, fileUrl) in
    if let fileUrl = fileUrl {
        // do something you want.
    }
}
```

Utility functions help you to reprocess image or video.
You can resize by given width, height with keep image rate, resize the you want or crop center square and so on for captured image or video by utility function.

```swift
HJCameraManager.shared().captureStillImage { (status:HJCameraManagerStatus, image:UIImage?, fileUrl:URL?) in
    if let image = image {
        HJCameraManager.processingImage(image, type: .cropCenterSquare, referenceSize: .zero, completion: { (status, image, fileUrl) in
            if let image = image {
                // do something you want.
            }
        })
    }
}

HJCameraManager.shared().stopRecordingVideo({ (status, image, fileUrl) in
    if let fileUrl = fileUrl {
        HJCameraManager.processingVideo(fileUrl, toOutputFileUrl: outputFileUrl, type: .cropCenterSquare, referenceSize: .zero, preset: AVAssetExportPresetHighestQuality, completion: { (status, image, fileUrl) in
            if let fileUrl = fileUrl {
                // do something you want.
            }
        })
    }
}
```

Observe HJCameraManager event to deal with business logic.

```swift
NotificationCenter.default.addObserver(self, selector:#selector(cameraManagerReport), name:NSNotification.Name(rawValue: HJCameraManagerNotification), object:nil)
```

You can do all things with changing camera device position, video orientation, preview mode.

# License

MIT License, where applicable. http://en.wikipedia.org/wiki/MIT_License
