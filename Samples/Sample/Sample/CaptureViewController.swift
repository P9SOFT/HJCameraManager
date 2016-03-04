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
        self.view.backgroundColor = UIColor.whiteColor()
        
        cameraView = NSBundle.mainBundle().loadNibNamed("CameraView", owner:self, options:nil).first as? CameraView
        if cameraView == nil {
            return
        }
        self.view.addSubview(cameraView!)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"cameraManagerReport:", name:HJCameraManagerNotification, object:nil)
        cameraView!.flashButton.addTarget(self, action:"flashButtonTouchUpInside:", forControlEvents:UIControlEvents.TouchUpInside)
        cameraView!.positionButton.addTarget(self, action:"positionButtonTouchUpInside:", forControlEvents:UIControlEvents.TouchUpInside)
        cameraView!.captureButton.addTarget(self, action:"captureButtonTouchUpInside:", forControlEvents:UIControlEvents.TouchUpInside)
    }
    
    deinit {
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        var frame:CGRect = self.view.bounds
        frame.origin.y += UIApplication.sharedApplication().statusBarFrame.size.height
        frame.size.height -= UIApplication.sharedApplication().statusBarFrame.size.height
        cameraView?.frame = frame
    }
    
    override func viewDidAppear(animated: Bool) {
        
        super.viewDidAppear(animated)
        
        // start camera when view did appear
        let cameraStatus = HJCameraManager.sharedManager().startWithPreviewView(cameraView!.frameView, preset: AVCaptureSessionPresetPhoto)
        self.updateCameraStatus(cameraStatus)
    }
    
    override func viewDidDisappear(animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        // stop camera when view did disappear
        HJCameraManager.sharedManager().stop()
    }
    
    func cameraManagerReport(notification:NSNotification) {
        
        // you can write code as below for result handling, but in this case, just print log.
        // because we already pass the code for result handler when requesting data at 'captureButtonTouchUpInside'.
        if let userInfo = notification.userInfo {
            print(userInfo)
        }
    }
    
    func flashButtonTouchUpInside(sender: AnyObject) {
        
        let currentFlashMode = HJCameraManager.sharedManager().flashMode
        var nextFlashMode:HJCameraManagerFlashMode?
        
        switch( currentFlashMode ) {
        case HJCameraManagerFlashModeOff :
            nextFlashMode = HJCameraManagerFlashModeOn
        case HJCameraManagerFlashModeOn :
            nextFlashMode = HJCameraManagerFlashModeAuto
        case HJCameraManagerFlashModeAuto :
            nextFlashMode = HJCameraManagerFlashModeOff
        default :
            nextFlashMode = currentFlashMode
        }
        if currentFlashMode != nextFlashMode {
            // change flash mode of camera
            HJCameraManager.sharedManager().flashMode = nextFlashMode!
            self.updateCameraStatus(true)
        }
    }
    
    func positionButtonTouchUpInside(sender: AnyObject) {
        
        let currentPosition = HJCameraManager.sharedManager().devicePosition
        var nextPosition:HJCameraManagerDevicePosition?
        
        switch( currentPosition ) {
        case HJCameraManagerDevicePositionBack :
            nextPosition = HJCameraManagerDevicePositionFront
        case HJCameraManagerDevicePositionFront :
            nextPosition = HJCameraManagerDevicePositionBack
        default :
            nextPosition = currentPosition
        }
        if currentPosition != nextPosition {
            // change device position of camera
            HJCameraManager.sharedManager().devicePosition = nextPosition!
            self.updateCameraStatus(true)
        }
    }
    
    func captureButtonTouchUpInside(sender: AnyObject) {
        
        // capture still image from camera.
        // you can also write code for result handling with response of notification handler 'cameraManagerReport' as above.
        HJCameraManager.sharedManager().captureStillImage { (status:HJCameraManagerStatus, image:UIImage!) -> Void in
            if image != nil {
                let photoViewController = PhotoViewController()
                photoViewController.image = image
                self.navigationController?.pushViewController(photoViewController, animated:true)
            }
        }
    }
    
    func updateCameraStatus(enable:Bool) {
        
        var flashTitle:String?
        switch( HJCameraManager.sharedManager().flashMode ) {
        case HJCameraManagerFlashModeOff :
            flashTitle = "Flash Off"
        case HJCameraManagerFlashModeOn :
            flashTitle = "Flash On"
        case HJCameraManagerFlashModeAuto :
            flashTitle = "Flash Auto"
        default :
            flashTitle = "Flash ?"
        }
        var positionTitle:String?
        switch( HJCameraManager.sharedManager().devicePosition ) {
        case HJCameraManagerDevicePositionBack :
            positionTitle = "Back"
        case HJCameraManagerDevicePositionFront :
            positionTitle = "Front"
        default :
            positionTitle = "?"
        }
        cameraView?.flashButton.enabled = enable
        cameraView?.positionButton.enabled = enable
        cameraView?.captureButton.enabled = enable
        cameraView?.flashButton.setTitle(flashTitle, forState:UIControlState.Normal)
        cameraView?.positionButton.setTitle(positionTitle, forState:UIControlState.Normal)
    }
}

