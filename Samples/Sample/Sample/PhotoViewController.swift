//
//  PhotoViewController.swift
//  Sample
//
//  Created by Tae Hyun Na on 2016. 3. 3.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

import UIKit
import Photos

class PhotoViewController: UIViewController {
    
    private let scrollView:UIScrollView = UIScrollView()
    private let imageView:UIImageView = UIImageView()
    private let label:UILabel = UILabel()
    private let saveToCameraRollButton = UIButton(type: .custom)
    
    var image:UIImage? {
        didSet {
            if let image = image {
                imageView.image = image
                label.text = "resolution \(image.size.width)x\(image.size.height), scale factor \(image.scale)\r\nback to swipe back."
            } else {
                imageView.image = nil
                label.text = "no image\r\nback to swipe back."
            }
            updateLayout()
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = false;
        view.backgroundColor = .black
        
        label.font = UIFont.boldSystemFont(ofSize: 9)
        label.textColor = .white
        label.backgroundColor = UIColor.init(white: 0, alpha: 0.2)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 2
        label.textAlignment = .center
        
        saveToCameraRollButton.backgroundColor = .darkGray
        saveToCameraRollButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        saveToCameraRollButton.setTitleColor(.white, for: .normal)
        saveToCameraRollButton.setTitle("Save To CameraRoll", for: .normal)
        
        imageView.contentMode = .scaleAspectFill
        
        scrollView.delegate = self;
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.backgroundColor = .clear
        scrollView.addSubview(imageView)
        
        view.addSubview(scrollView)
        view.addSubview(label)
        view.addSubview(saveToCameraRollButton)
        
        saveToCameraRollButton.addTarget(self, action:#selector(saveToCameraRollButtonTouchUpInside(sender:)), for:.touchUpInside)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateLayout()
    }
    
    private func updateUpdateToCenterOfViewForScrollView(view:UIView, scrollView:UIScrollView) {
        
        let containerSize = scrollView.bounds.size
        var frame = view.frame
        frame.origin.x = (frame.size.width < containerSize.width) ? ((containerSize.width-frame.size.width)*0.5) : 0.0
        frame.origin.y = (frame.size.height < containerSize.height) ? ((containerSize.height-frame.size.height)*0.5) : 0.0
        view.frame = frame
    }
    
    private func updateLayout() {
        
        var frame:CGRect = view.bounds
        frame.origin.y += UIApplication.shared.statusBarFrame.size.height
        frame.size.height -= UIApplication.shared.statusBarFrame.size.height
        scrollView.frame = frame
        if let image = imageView.image {
            var imageFrame:CGRect = .zero
            if frame.size.width < frame.size.height {
                imageFrame.size.width = scrollView.bounds.size.width
                imageFrame.size.height = image.size.height * (scrollView.bounds.size.width/image.size.width)
            } else {
                imageFrame.size.height = scrollView.bounds.size.height
                imageFrame.size.width = image.size.width * (scrollView.bounds.size.height/image.size.height)
            }
            imageFrame.size.width *= scrollView.zoomScale
            imageFrame.size.height *= scrollView.zoomScale
            scrollView.contentSize = imageFrame.size
            imageView.frame = imageFrame
            imageView.image = image
            updateUpdateToCenterOfViewForScrollView(view: imageView, scrollView:scrollView)
            var labelFrame:CGRect = .zero
            labelFrame.size.width = ((label.text ?? "-") as NSString).size(withAttributes: [NSAttributedString.Key.font:label.font]).width + 10
            labelFrame.size.height = 30
            labelFrame.origin.x = (frame.size.width - labelFrame.size.width)*0.5
            labelFrame.origin.y = 40
            label.frame = labelFrame
            var buttonFrame:CGRect = .zero
            buttonFrame.size.width = 140
            buttonFrame.size.height = 30
            buttonFrame.origin.x = (frame.size.width - buttonFrame.size.width)*0.5
            buttonFrame.origin.y = frame.size.height - 20 - buttonFrame.size.height
            saveToCameraRollButton.frame = buttonFrame
        }
    }
    
    @objc func saveToCameraRollButtonTouchUpInside(sender: AnyObject) {
        
        guard let image = image else {
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { (success, error) in
            let alert = UIAlertController(title: nil, message: (success == false ? "Save Failed" : "Save OK"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        })
    }
}

extension PhotoViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        
        self.updateUpdateToCenterOfViewForScrollView(view: imageView, scrollView:scrollView)
    }
}
