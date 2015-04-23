//
//  ShareViewController.swift
//  ShareAction
//
//  Created by Jeff Tilson on 2015-03-27.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import UIKit
import Social
import Alamofire
import SwiftyJSON
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    
    // MARK: - Class constants/vars
    
    // Spot API constants
    let spotApiKey = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")!.stringForKey("api_key_preference")!
    let spotApiUrl = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")!.stringForKey("api_endpoint_preference")!
    
    let sharedDefaults = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")

    // MARK: - SLComposeServiceViewController

    // Perform tasks when the view is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.hidden = true
        
        // Check for access token
        if let accessToken = self.sharedDefaults?.objectForKey("spot_access_token") as? NSString {
            // Good, got a token. Let's check if we can talk to the server
            let method = "util.ping"
            let endpoint = spotApiUrl + method
            
            var ping_parameters = [
                "api_key": self.spotApiKey
            ]
            
            println("Attempting ping..")
            
            Alamofire.request(.GET, endpoint, parameters: ping_parameters, encoding: .URL)
                .responseJSON{ (request, response, data, error) in
                    if (error != nil) {
                        if let uError = error {
                            // Ok, had an error
                            if let errorCode = error?.code as Int? {
                                // Hide view and text input
                                self.view.hidden = true
                                self.textView.removeFromSuperview()

                                var title: String = uError.localizedDescription
                                var message: String
                                
                                if let reason = uError.localizedFailureReason {
                                    message = reason
                                } else {
                                    message = title
                                    title = "Error"
                                }

                                // Check error codes here
                                switch (errorCode) {
                                case -1003:
                                    title = "Oops"
                                    message = "Can't find Spot server! Check your internet connection and try again."
                                    break
                                default:
                                    break
                                }
                                
                                let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
                                
                                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                                    self.completeExtension()
                                }))
                                
                                self.presentViewController(alertController, animated: true, completion: nil)
                            }
                        }
                    } else {
                        // No error, show the view already!
                        self.view.hidden = false
                    }
            }
            
        } else {
            self.view.hidden = true
            self.textView.removeFromSuperview() // Scorched earth.. remove the textView from the view controller (only way I could figure out how to prevent it from popping up here)
           
            let alertController = UIAlertController(title: "Oops", message:
                "Looks like you haven't logged in to Spot! Switch to the Spot Connect app and log in before trying to share again.", preferredStyle: UIAlertControllerStyle.Alert)
            
            alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                self.completeExtension()
            }))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    // Do validation of contentText and/or NSExtensionContext attachments here
    override func isContentValid() -> Bool {
        return true
    }

    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    override func didSelectPost() {
        // Get the access token from shared defaults
        self.sharedDefaults?.synchronize()
        if let accessToken = self.sharedDefaults?.objectForKey("spot_access_token") as? NSString {
           
            // Get item provider
            var item : NSExtensionItem = self.extensionContext?.inputItems[0] as! NSExtensionItem
            
            var itemProvider: NSItemProvider = item.attachments?.last as! NSItemProvider

            // If we support a URL
            if (itemProvider.hasItemConformingToTypeIdentifier("public.url")) {
                itemProvider.loadItemForTypeIdentifier("public.url", options: nil, completionHandler: { (urlItem, error) -> Void in
                    if let url = urlItem as? NSURL {
                        // Finally.. got the URL. Lets post the bookmark
                        self.postBookmark(self.contentText as String, url: url, token: accessToken)
                    }
                })
            } else if (itemProvider.hasItemConformingToTypeIdentifier("public.text")) {
                // Support just text
                itemProvider.loadItemForTypeIdentifier("public.text", options: nil, completionHandler: { (item, error) -> Void in
                    if let text = item as? String {
                        // Make a wire post
                        self.postWire(text, token: accessToken)
                    }
                })
            }
        }
    }
    
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    override func configurationItems() -> [AnyObject]! {
        return []
    }
    
    // MARK: - Helpers
    
    // Complete extension
    func completeExtension() -> Void {
        self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
    }
    
    // Post a bookmark
    func postBookmark(title: String, url: NSURL, token: NSString) -> Void {
        let method = "bookmark.post"
        let endpoint = spotApiUrl + method
        
        var post_parameters = [
            "title": title,
            "url": url.URLString,
            "api_key": self.spotApiKey,
            "auth_token": token
        ]
        
        
        // Success/Error messages
        var message: String = ""
        var title: String = ""
        
        Alamofire.request(.POST, endpoint, parameters: post_parameters, encoding: .JSON)
            .responseJSON{ (request, response, data, error) in
                // Check for errors
                if (error != nil) {
                    if let uError = error {
                        title = uError.localizedDescription
                        
                        if let reason = uError.localizedFailureReason {
                            message = reason
                        } else {
                            message = title
                            title = "error"
                        }
                    }
                } else {                    
                    var json = JSON(data!)
                    
                    // Check for an API error
                    if (json["status"] >= 0) {
                        // good.. show success
                        title = "Success!"
                        message = "Posted to Spot!"
                    } else {
                        title = "Error"
                        message = json["message"].stringValue
                    }
                }
                
                let alertController = UIAlertController(title: title, message:
                    message, preferredStyle: UIAlertControllerStyle.Alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                    self.completeExtension()
                }))
                
                self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    // Make a wire post
    func postWire(text: String, token: NSString) -> Void {
        let method = "thewire.post"
        let endpoint = spotApiUrl + method
        
        var post_parameters = [
            "text": text,
            "api_key": self.spotApiKey,
            "auth_token": token
        ]
        
        // Success/Error messages
        var message: String = ""
        var title: String = ""
        
        Alamofire.request(.POST, endpoint, parameters: post_parameters, encoding: .JSON)
            .responseJSON{ (request, response, data, error) in
                // Check for errors
                if (error != nil) {
                    if let uError = error {
                        title = uError.localizedDescription
                        
                        if let reason = uError.localizedFailureReason {
                            message = reason
                        } else {
                            message = title
                            title = "error"
                        }
                    }
                } else {
                    var json = JSON(data!)
                    
                    // Check for an API error
                    if (json["status"] >= 0) {
                        // good.. show success
                        title = "Success!"
                        message = "Posted to Spot!"
                    } else {
                        title = "Error"
                        message = json["message"].stringValue
                    }
                    
                }
                
                let alertController = UIAlertController(title: title, message:
                    message, preferredStyle: UIAlertControllerStyle.Alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                    self.completeExtension()
                }))
                
                self.presentViewController(alertController, animated: true, completion: nil)
        }
    }

}
