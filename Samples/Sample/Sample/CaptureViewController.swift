//
//  CaptureViewController.swift
//  Sample
//
//  Created by Tae Hyun Na on 2016. 3. 3.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

import UIKit

class CaptureViewController: UIViewController {
    
    var cameraView:CameraView?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false;
        self.view.backgroundColor = .white
        
        cameraView = Bundle.main.loadNibNamed("CameraView", owner:self, options:nil)?.first as? CameraView
        guard let cameraView = cameraView else {
            return
        }
        self.view.addSubview(cameraView)
        
        NotificationCenter.default.addObserver(self, selector:#selector(cameraManagerReport), name:NSNotification.Name(rawValue: HJCameraManagerNotification), object:nil)
        
        cameraView.flashButton.addTarget(self, action:#selector(flashButtonTouchUpInside(sender:)), for:.touchUpInside)
        cameraView.positionButton.addTarget(self, action:#selector(positionButtonTouchUpInside(sender:)), for:.touchUpInside)
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
        cameraView?.frame = frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        // start camera when view did appear
        let cameraStatus = HJCameraManager.shared().start(withPreviewView: cameraView!.frameView, preset: AVCaptureSession.Preset.photo.rawValue)
        self.updateCameraStatus(enable: cameraStatus)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        // stop camera when view did disappear
        HJCameraManager.shared().stop()
    }
    
    @objc func cameraManagerReport(notification:NSNotification) {
        
        // you can write code as below for result handling, but in this case, just print log.
        // because we already pass the code for result handler when requesting data at 'captureButtonTouchUpInside'.
        if let userInfo = notification.userInfo {
            print(userInfo)
        }
    }
    
    @objc func flashButtonTouchUpInside(sender: AnyObject) {
        
        let currentFlashMode = HJCameraManager.shared().flashMode
        var nextFlashMode:HJCameraManagerFlashMode?
        
        switch( currentFlashMode ) {
        case .off :
            nextFlashMode = .on
        case .on :
            nextFlashMode = .auto
        case .auto :
            nextFlashMode = .off
        default :
            nextFlashMode = currentFlashMode
        }
        if currentFlashMode != nextFlashMode {
            // change flash mode of camera
            HJCameraManager.shared().flashMode = nextFlashMode!
            self.updateCameraStatus(enable: true)
        }
    }
    
    @objc func positionButtonTouchUpInside(sender: AnyObject) {
        
        let currentPosition = HJCameraManager.shared().devicePosition
        var nextPosition:HJCameraManagerDevicePosition?
        
        switch( currentPosition ) {
        case .back :
            nextPosition = .front
        case .front :
            nextPosition = .back
        default :
            nextPosition = currentPosition
        }
        if currentPosition != nextPosition {
            // change device position of camera
            HJCameraManager.shared().devicePosition = nextPosition!
            self.updateCameraStatus(enable: true)
        }
    }
    
    @objc func stillCaptureButtonTouchUpInside(sender: AnyObject) {
        
        // capture still image from camera.
        // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
        HJCameraManager.shared().captureStillImage { (status:HJCameraManagerStatus, image:UIImage?) in
            if let image = image {
                let photoViewController = PhotoViewController()
                photoViewController.image = image
                self.navigationController?.pushViewController(photoViewController, animated:true)
            }
        }
    }
    
    @objc func previewCaptureButtonTouchUpInside(sender: AnyObject) {
        
        // capture preview image from camera.
        // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
        HJCameraManager.shared().capturePreviewImage({ (status:HJCameraManagerStatus, image:UIImage?) in
            if let image = image {
                let photoViewController = PhotoViewController()
                photoViewController.image = image
                self.navigationController?.pushViewController(photoViewController, animated:true)
            }
        })
    }
    
    func updateCameraStatus(enable:Bool) {
        
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
            positionTitle = "?"
        }
        cameraView?.flashButton.isEnabled = enable
        cameraView?.positionButton.isEnabled = enable
        cameraView?.stillCaptureButton.isEnabled = enable
        cameraView?.previewCaptureButton.isEnabled = enable
        cameraView?.flashButton.setTitle(flashTitle, for:.normal)
        cameraView?.positionButton.setTitle(positionTitle, for:.normal)
    }
}

