//
//  CaptureViewController.swift
//  Sample
//
//  Created by Tae Hyun Na on 2016. 3. 3.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

import UIKit
import Photos
import AVKit

class CaptureViewController: UIViewController {
    
    private var isVideoMode:Bool = false
    private let cameraView:CameraView = Bundle.main.loadNibNamed("CameraView", owner:self, options:nil)?.first as! CameraView
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false;
        self.view.backgroundColor = .white
        
        self.view.addSubview(cameraView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChangeHandler), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(cameraManagerReport), name:NSNotification.Name(rawValue: HJCameraManagerNotification), object:nil)
        
        cameraView.photoButton.addTarget(self, action:#selector(photoButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.videoButton.addTarget(self, action:#selector(videoButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.flashButton.addTarget(self, action:#selector(flashButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.positionButton.addTarget(self, action:#selector(positionButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.contentModeButton.addTarget(self, action:#selector(contentModeButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.stillCaptureButton.addTarget(self, action:#selector(stillCaptureButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.previewCaptureButton.addTarget(self, action:#selector(previewCaptureButtonTouchUpInside(sender:)), for:.touchUpInside)
    }
    
    deinit {
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        var frame:CGRect = self.view.bounds
        frame.origin.y += UIApplication.shared.statusBarFrame.size.height
        frame.size.height -= UIApplication.shared.statusBarFrame.size.height
        cameraView.frame = frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        if( UIDevice.current.orientation != .portraitUpsideDown ) {
            HJCameraManager.shared().setVideoOrientationByDeviceOrietation(UIDevice.current.orientation)
        }
        
        // start camera when view did appear
        stanbyCameraByCurrentMode()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        // stop camera when view did disappear
        HJCameraManager.shared().stop()
    }
    
    @objc func deviceOrientationDidChangeHandler(notification:NSNotification) {
        
        if( UIDevice.current.orientation != .portraitUpsideDown ) {
            HJCameraManager.shared().setVideoOrientationByDeviceOrietation(UIDevice.current.orientation)
        }
    }
    
    @objc func cameraManagerReport(notification:NSNotification) {
        
        // you can write code as below for result handling, but in this case, just print log.
        // because we already pass the code for result handler when requesting data at 'captureButtonTouchUpInside'.
        if let userInfo = notification.userInfo {
            print(userInfo)
        }
    }
    
    @objc func photoButtonTouchUpInside(sender: AnyObject) {
        
        if isVideoMode == false {
            return
        }
        isVideoMode = false
        
        stanbyCameraByCurrentMode()
    }
    
    @objc func videoButtonTouchUpInside(sender: AnyObject) {
        
        if isVideoMode == true {
            return
        }
        isVideoMode = true
        
        stanbyCameraByCurrentMode()
    }
    
    @objc func flashButtonTouchUpInside(sender: AnyObject) {
        
        let currentFlashMode = HJCameraManager.shared().flashMode
        var nextFlashMode:HJCameraManagerFlashMode = .off

        switch( currentFlashMode ) {
        case .off :
            nextFlashMode = .on
        case .on :
            nextFlashMode = .auto
        default :
            nextFlashMode = .off
        }
        if currentFlashMode != nextFlashMode {
            // change flash mode of camera
            HJCameraManager.shared().flashMode = nextFlashMode
            updateCameraStatus(enable: true)
        }
    }
    
    @objc func positionButtonTouchUpInside(sender: AnyObject) {
        
        let currentPosition = HJCameraManager.shared().devicePosition
        var nextPosition:HJCameraManagerDevicePosition = .back
        
        switch( currentPosition ) {
        case .back :
            nextPosition = .front
        default :
            nextPosition = .back
        }
        if currentPosition != nextPosition {
            // change device position of camera
            HJCameraManager.shared().devicePosition = nextPosition
            updateCameraStatus(enable: true)
        }
    }
    
    @objc func contentModeButtonTouchUpInside(sender: AnyObject) {
        
        let currentContentMode = HJCameraManager.shared().previewContentMode
        var nextContentMode:HJCameraManagerPreviewContentMode = .resizeAspect
        
        switch( currentContentMode ) {
        case .resizeAspect :
            nextContentMode = .resizeAspectFill
        case .resizeAspectFill :
            nextContentMode = .resize
        default :
            nextContentMode = .resizeAspect
        }
        if currentContentMode != nextContentMode {
            // change preview content mode
            HJCameraManager.shared().previewContentMode = nextContentMode
            updateCameraStatus(enable: true)
        }
    }
    
    @objc func stillCaptureButtonTouchUpInside(sender: AnyObject) {
        
        if isVideoMode == false {
            // capture still image from camera.
            // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
            HJCameraManager.shared().captureStillImage { (status:HJCameraManagerStatus, image:UIImage?, fileUrl:URL?) in
                if let image = image {
                    var imageProcessingType:HJCameraManagerImageProcessingType = .pass
                    switch HJCameraManager.shared().previewContentMode {
                    case .resizeAspectFill :
                        imageProcessingType = .cropCenterSquare
                    case .resize :
                        imageProcessingType = .resizeByGivenRate
                    default :
                        break;
                    }
                    HJCameraManager.processingImage(image, type: imageProcessingType, referenceSize: self.cameraView.frameView.frame.size, completion: { (status, image, fileUrl) in
                        if let image = image {
                            let photoViewController = PhotoViewController()
                            photoViewController.image = image
                            self.navigationController?.pushViewController(photoViewController, animated:true)
                        }
                    })
                }
            }
        } else {
            // record video or stop
            // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
            if HJCameraManager.shared().isVideoRecording == false {
                cameraView.stillCaptureButton.setTitle("Stop", for: .normal)
                let saveVideoPath = "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/output.mov"
                let url = URL(fileURLWithPath: saveVideoPath)
                HJCameraManager.shared().recordVideo(toFileUrl: url)
            } else {
                cameraView.stillCaptureButton.setTitle("Record", for: .normal)
                cameraView.stillCaptureButton.isEnabled = false
                HJCameraManager.shared().stopRecordingVideo({ (status, image, fileUrl) in
                    self.cameraView.stillCaptureButton.isEnabled = true
                    if let fileUrl = fileUrl {
                        var imageProcessingType:HJCameraManagerImageProcessingType?
                        switch HJCameraManager.shared().previewContentMode {
                        case .resizeAspectFill :
                            imageProcessingType = .cropCenterSquare
                        case .resize :
                            imageProcessingType = .resizeByGivenRate
                        default :
                            break;
                        }
                        if let type = imageProcessingType {
                            self.cameraView.stillCaptureButton.isEnabled = false
                            let saveVideoPath = "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/output2.mov"
                            let outputFileUrl = URL(fileURLWithPath: saveVideoPath)
                            HJCameraManager.processingVideo(fileUrl, toOutputFileUrl: outputFileUrl, type: type, referenceSize: self.cameraView.frameView.frame.size, preset: AVAssetExportPresetHighestQuality, completion: { (status, image, fileUrl) in
                                self.cameraView.stillCaptureButton.isEnabled = true
                                if let fileUrl = fileUrl {
                                    self.handleRecodingResult(fileUrl: fileUrl)
                                }
                            })
                        } else {
                            self.handleRecodingResult(fileUrl: fileUrl)
                        }
                    }
                })
            }
        }
    }
    
    @objc func previewCaptureButtonTouchUpInside(sender: AnyObject) {
        
        // capture preview image from camera.
        // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
        HJCameraManager.shared().capturePreviewImage { (status:HJCameraManagerStatus, image:UIImage?, fileUrl:URL?) in
            if let image = image {
                var imageProcessingType:HJCameraManagerImageProcessingType = .pass
                switch HJCameraManager.shared().previewContentMode {
                case .resizeAspectFill :
                    imageProcessingType = .cropCenterSquare
                case .resize :
                    imageProcessingType = .resizeByGivenRate
                default :
                    break;
                }
                HJCameraManager.processingImage(image, type: imageProcessingType, referenceSize: self.cameraView.frameView.frame.size, completion: { (status, image, fileUrl) in
                    if let image = image {
                        let photoViewController = PhotoViewController()
                        photoViewController.image = image
                        self.navigationController?.pushViewController(photoViewController, animated:true)
                    }
                })
            }
        }
    }
    
    private func stanbyCameraByCurrentMode() {
        
        if HJCameraManager.shared().isRunning == true {
            HJCameraManager.shared().stop()
        }
        var cameraStatus = false
        if isVideoMode == false {
            cameraStatus = HJCameraManager.shared().startWithPreviewView(forPhoto: cameraView.frameView)
        } else {
            cameraStatus = HJCameraManager.shared().startWithPreviewView(forVideo: cameraView.frameView, enableAudio: false)
        }
        updateCameraStatus(enable: cameraStatus)
    }
    
    private func updateCameraStatus(enable:Bool) {
        
        cameraView.photoButton.setTitle((isVideoMode == false ? "🔘 Photo" : "⚪️ Photo"), for: .normal)
        cameraView.videoButton.setTitle((isVideoMode == false ? "⚪️ Video" : "🔘 Video"), for: .normal)
        var flashTitle:String?
        switch( HJCameraManager.shared().flashMode ) {
        case .off :
            flashTitle = "Flash Off"
        case .on :
            flashTitle = "Flash On"
        case .auto :
            flashTitle = "Flash Auto"
        default :
            flashTitle = "Flash ?"
        }
        
        var positionTitle:String?
        switch( HJCameraManager.shared().devicePosition ) {
        case .back :
            positionTitle = "Back"
        case .front :
            positionTitle = "Front"
        default :
            positionTitle = "Position ?"
        }
        var contentModeTitle:String?
        switch( HJCameraManager.shared().previewContentMode ) {
        case .resizeAspect :
            contentModeTitle = "Aspect"
        case .resizeAspectFill :
            contentModeTitle = "AspectFill"
        case .resize :
            contentModeTitle = "Resize"
        default :
            contentModeTitle = "Mode ?"
        }
        if isVideoMode == false {
            cameraView.stillCaptureButton.setTitle("Still Capture", for: .normal)
        } else {
            cameraView.stillCaptureButton.setTitle((HJCameraManager.shared().isVideoRecording == false ? "Record" : "Stop"), for: .normal)
        }
        cameraView.flashButton.isEnabled = enable
        cameraView.positionButton.isEnabled = enable
        cameraView.contentModeButton.isEnabled = enable
        cameraView.stillCaptureButton.isEnabled = enable
        cameraView.previewCaptureButton.isEnabled = enable
        cameraView.flashButton.setTitle(flashTitle, for:.normal)
        cameraView.positionButton.setTitle(positionTitle, for:.normal)
        cameraView.contentModeButton.setTitle(contentModeTitle, for: .normal)
        cameraView.photoButton.isEnabled = (enable == true ? !HJCameraManager.shared().isVideoRecording : false)
        cameraView.videoButton.isEnabled = (enable == true ? !HJCameraManager.shared().isVideoRecording : false)
    }
    
    private func handleRecodingResult(fileUrl:URL) {
        
        let alert = UIAlertController(title: nil, message: "Play or Save?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { (action) in
            let playerViewController = AVPlayerViewController()
            playerViewController.player = AVPlayer(url: fileUrl)
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        }))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { (action) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl)
            }, completionHandler: { (success, error) in
                if success == false {
                    print("save failed")
                } else {
                    print("save ok")
                }
            })
        }))
        present(alert, animated: true, completion: nil)
    }
}

