P9CameraManager
============

Easy, and quick library for handling iOS camera.

# Installation

You can download the latest framework files from our Release page.
P9CameraManager also available through CocoaPods. To install it simply add the following line to your Podfile.
pod ‘P9CameraManager’

# Play

You can choose starting mode to capture photo or video.

Start preview to taking photo like this,

```swift
P9CameraManager.shared().startWithPreviewView(forPhoto: cameraView)
```

and, video.

```swift
P9CameraManager.shared().startWithPreviewView(forVideo: cameraView, enableAudio: false)
```

or, choose start for custom setting and preset you want.

```swift
P9CameraManager.shared().start(withPreviewView: cameraView, preset: AVCaptureSessionPreset3840x2160, enableVideo: true, enableAudio: false)
```

Now, Take a picture.

```swift
P9CameraManager.shared().captureStillImage { (status:P9CameraManagerStatus, image:UIImage?, fileUrl:URL?) in
    if let image = image {
        // do something you want.
    }
}
```

Another way to take a picture. It provide smaller image then captureStillImage but no shutter sound.

```swift
P9CameraManager.shared().capturePreviewImage { (status:P9CameraManagerStatus, image:UIImage?, fileUrl:URL?) in
    if let image = image {
        // do something you want.
    }
}
```

And, recoding video like this.

```swift
P9CameraManager.shared().recordVideo(toFileUrl: url)
```

Stop recording.

```swift
P9CameraManager.shared().stopRecordingVideo({ (status, image, fileUrl) in
    if let fileUrl = fileUrl {
        // do something you want.
    }
}
```

Utility functions help you to reprocess image or video.
You can resize by given width, height with keep image rate, resize the you want or crop center square and so on for captured image or video by utility function.

```swift
P9CameraManager.shared().captureStillImage { (status:P9CameraManagerStatus, image:UIImage?, fileUrl:URL?) in
    if let image = image {
        P9CameraManager.processingImage(image, type: .cropCenterSquare, referenceSize: .zero, completion: { (status, image, fileUrl) in
            if let image = image {
                // do something you want.
            }
        })
    }
}

P9CameraManager.shared().stopRecordingVideo({ (status, image, fileUrl) in
    if let fileUrl = fileUrl {
        P9CameraManager.processingVideo(fileUrl, toOutputFileUrl: outputFileUrl, type: .cropCenterSquare, referenceSize: .zero, preset: AVAssetExportPresetHighestQuality, completion: { (status, image, fileUrl) in
            if let fileUrl = fileUrl {
                // do something you want.
            }
        })
    }
}
```

Observe P9CameraManager event to deal with business logic.

```swift
NotificationCenter.default.addObserver(self, selector:#selector(cameraManagerReport), name:NSNotification.Name(rawValue: P9CameraManagerNotification), object:nil)
```

For example, you can get every frame of previewing image.

```swift
@objc func cameraManagerReport(notification:NSNotification) {
    guard let userInfo = notification.userInfo, let status = P9CameraManagerStatus(rawValue: userInfo[P9CameraManagerNotifyParameterKeyStatus] as? Int ?? 0) else {
        return
    }
    if status == .previewImageCaptured, let image = userInfo[P9CameraManagerNotifyParameterKeyImage] as? UIImage {
        // do something you want.
    }
}
```

You can do all things with changing camera device position, video orientation, preview mode.

# License

MIT License, where applicable. http://en.wikipedia.org/wiki/MIT_License
