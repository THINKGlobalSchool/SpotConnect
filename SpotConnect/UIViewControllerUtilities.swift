//
//  UIViewControllerUtilities.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-04-17.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import Foundation
import UIKit

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
}