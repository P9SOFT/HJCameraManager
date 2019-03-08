//
//  PhotoViewController.swift
//  Sample
//
//  Created by Tae Hyun Na on 2016. 3. 3.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

import UIKit

class PhotoViewController: UIViewController, UIScrollViewDelegate {
    
    private let scrollView:UIScrollView = UIScrollView()
    private let imageView:UIImageView = UIImageView()
    private let label:UILabel = UILabel()
    
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
        
        scrollView.delegate = self;
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)
        
        imageView.contentMode = .scaleAspectFill
        
        label.font = UIFont.boldSystemFont(ofSize: 9)
        label.textColor = .white
        label.backgroundColor = UIColor.init(white: 0, alpha: 0.2)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 2
        label.textAlignment = .center
        
        scrollView.addSubview(imageView)
        
        view.addSubview(label)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateLayout()
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        
        return imageView
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        self.updateUpdateToCenterOfViewForScrollView(view: imageView, scrollView:scrollView)
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
        }
    }
}
