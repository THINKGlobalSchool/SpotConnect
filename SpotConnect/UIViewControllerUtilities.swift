//
//  UIViewControllerUtilities.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-04-17.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import Foundation
import UIKit

struct SpotColors {
    static var LIGHTRED: CGColor = UIColor(red:171/255, green:51/255, blue:45/255, alpha:1).CGColor
    static var DARKRED: CGColor = UIColor(red:127/255, green:19/255, blue: 25/255, alpha:1).CGColor
}

extension UIViewController {

    // Show a message with a dismiss action
    func showMessage(title: NSString, dismiss: NSString, message: NSString) {
        let alertController = UIAlertController(title: title.description, message:
            message.description, preferredStyle: UIAlertControllerStyle.Alert)
        
        alertController.addAction(UIAlertAction(title: dismiss.description, style: UIAlertActionStyle.Default,handler: nil))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    // Show a message without a dismiss action
    func showMessage(title: NSString, message: NSString) {
        let alertController = UIAlertController(title: title.description, message:
            message.description, preferredStyle: UIAlertControllerStyle.Alert)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func showProgressHUD(label: String) ->Void {
        let progressText = label
        let progressHUD = ProgressHUD(text: progressText)
        self.view.addSubview(progressHUD)
        self.view.backgroundColor = UIColor(white: 1, alpha: 0.7)
    }
    
    func hideProgressHUD() -> Void {
        for view in self.view.subviews {
            if view.isKindOfClass(ProgressHUD) {
                if let progressView:ProgressHUD = view as? ProgressHUD {
                    progressView.hide()
                }
            }
        }
    }
    
    func twoColorLayerGradient(colorOne: CGColor, colorTwo: CGColor) {
        let layer : CAGradientLayer = CAGradientLayer()
        layer.frame.size = self.view.frame.size
        layer.frame.origin = CGPointMake(0.0,0.0)

        let color0 = colorOne
        let color1 = colorTwo
        
        layer.colors = [color0,color1]
        self.view.layer.insertSublayer(layer, atIndex: 0)
    }
}