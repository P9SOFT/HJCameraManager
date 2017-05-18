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
        self.view.backgroundColor = UIColor.white
        
        cameraView = Bundle.main.loadNibNamed("CameraView", owner:self, options:nil)?.first as? CameraView
        if cameraView == nil {
            return
        }
        self.view.addSubview(cameraView!)
        
        NotificationCenter.default.addObserver(self, selector:#selector(CaptureViewController.cameraManagerReport(_:)), name:NSNotification.Name(rawValue: HJCameraManagerNotification), object:nil)
        cameraView!.flashButton.addTarget(self, action:#selector(CaptureViewController.flashButtonTouchUpInside(_:)), for:UIControlEvents.touchUpInside)
        cameraView!.positionButton.addTarget(self, action:#selector(CaptureViewController.positionButtonTouchUpInside(_:)), for:UIControlEvents.touchUpInside)
        cameraView!.captureButton.addTarget(self, action:#selector(CaptureViewController.captureButtonTouchUpInside(_:)), for:UIControlEvents.touchUpInside)
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
        let cameraStatus = HJCameraManager.default().start(withPreviewView: cameraView!.frameView, preset: AVCaptureSessionPresetPhoto) 
        self.updateCameraStatus(cameraStatus)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        // stop camera when view did disappear
        HJCameraManager.default().stop()
    }
    
    func cameraManagerReport(_ notification:Notification) {
        
        // you can write code as below for result handling, but in this case, just print log.
        // because we already pass the code for result handler when requesting data at 'captureButtonTouchUpInside'.
        if let userInfo = notification.userInfo {
            print(userInfo)
        }
    }
    
    func flashButtonTouchUpInside(_ sender: AnyObject) {
        
        let currentFlashMode = HJCameraManager.default().flashMode 
        var nextFlashMode:HJCameraManagerFlashMode = .unspecified
        
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
            HJCameraManager.default().flashMode = nextFlashMode
            self.updateCameraStatus(true)
        }
    }
    
    func positionButtonTouchUpInside(_ sender: AnyObject) {
        
        let currentPosition = HJCameraManager.default().devicePosition 
        var nextPosition:HJCameraManagerDevicePosition = .unspecified
        
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
            HJCameraManager.default().devicePosition = nextPosition
            self.updateCameraStatus(true)
        }
    }
    
    func captureButtonTouchUpInside(_ sender: AnyObject) {
        
        // capture still image from camera.
        // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
        HJCameraManager.default().captureStillImage { (status:HJCameraManagerStatus, image:UIImage?) in
            if image != nil {
                let photoViewController = PhotoViewController()
                photoViewController.image = image
                self.navigationController?.pushViewController(photoViewController, animated:true)
            }
        }
    }
    
    func updateCameraStatus(_ enable:Bool) {
        
        var flashTitle:String?
        let flashMode = HJCameraManager.default().flashMode 
        
        switch( flashMode ) {
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
        let devicePosition = HJCameraManager.default().devicePosition 
        
        switch( devicePosition ) {
        case .back :
            positionTitle = "Back"
        case .front :
            positionTitle = "Front"
        default :
            positionTitle = "?"
        }
        cameraView?.flashButton.isEnabled = enable
        cameraView?.positionButton.isEnabled = enable
        cameraView?.captureButton.isEnabled = enable
        cameraView?.flashButton.setTitle(flashTitle, for:UIControlState())
        cameraView?.positionButton.setTitle(positionTitle, for:UIControlState())
    }
}

