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
    
    // Config constants
    let configurationApiEndpoint: String = "apiEndpoint"
    let configurationApiKey: String = "apiKey"
    let configurationApiAccessToken: String = "apiAccessToken"
    
    // Spot API constants
    var spotApiKey: String?
    var spotApiUrl: String?
    
    let sharedDefaults = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")

    // Items that can be shared
    var postUrl: NSURL?
    var postText: String?
    var postError: NSError?
    var postImages: [NSURL] = []
    
    // MARK: - SLComposeServiceViewController
    
    // Perform tasks when the view is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.spotApiKey = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")!.stringForKey(self.configurationApiKey)!
        self.spotApiUrl = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")!.stringForKey(self.configurationApiEndpoint)!
        
        self.view.hidden = true

        // Check for access token
        if let accessToken = self.sharedDefaults?.objectForKey("apiAccessToken") as? NSString {
            // Good, got a token. Let's check if we can talk to the server
            let method = "util.ping"
            let endpoint = self.spotApiUrl! + method
            
            var ping_parameters = [
                "api_key": self.spotApiKey!
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
                        
                        // Get item provider
                        var item : NSExtensionItem = self.extensionContext?.inputItems.first as! NSExtensionItem
                        
                        // Got more than one, this will be fun!
                        for provider in item.attachments! {
                            let itemProvider = provider as! NSItemProvider
                            self.setPostContent(itemProvider)
                        }
                        
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

    // Called when the view is finished presenting
    override func presentationAnimationDidFinish() {
     //
    }
    
    func setPostContent(itemProvider: NSItemProvider) -> Void {
        // Need to figure out what we're going to be posting, this is in decending order of importance
        var validTypes = [
            kUTTypePropertyList as String, // Propertly list, as returned by preprocessing JS (not currently in use)
            kUTTypeImage as String,        // public.image
            kUTTypeURL as String,          // public.url
            kUTTypeText as String,         // public.text
            kUTTypePlainText as String     // public.plain-text
        ]

        for type in validTypes {
            if (itemProvider.hasItemConformingToTypeIdentifier(type)) {
                itemProvider.loadItemForTypeIdentifier(type, options: nil, completionHandler: { (item, error) -> Void in
                    if let url = item as? NSURL {
                        // Check if this is web site or file reference URL
                        if url.fileURL {
                            // It's a file, assuming image for now
                            self.postImages.append(url)
                        } else {
                            self.postUrl = url
                        }
                    } else if let text = item as? String {
                        // Got text, but check to see what UTI type we were expecting
                        if type == kUTTypeURL as String {
                            // We've been told that this conforms to the public.url type, but we got a string? 
                            // (I'm looking at you Pocket)
                            // Fail for now..
                            self.postError = NSError(domain: "SpotConnect", code: -42, userInfo: [NSLocalizedDescriptionKey: "This app isn't providing the data we were told to expect from it. We won't be able to post from this app."])
                        } else {
                            // Got some text, as we should
                            self.postText = text
                        }
                    }
                })
            }
        }
    }

    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    override func didSelectPost() {
        // Check if we got any usable data
        if (self.postUrl == nil && self.postText == nil && self.postImages.count == 0) {
            // Nope..
            self.postError = NSError(domain: "SpotConnect", code: -43, userInfo: [NSLocalizedDescriptionKey: "This app isn't providing any usable data!"])
        }
        
       
        // Check if we generated an error trying to set post data
        if (self.postError != nil) {
            let alertController = UIAlertController(title: "Uh-oh", message:
                self.postError?.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
            
            alertController.addAction(UIAlertAction(title: "Ok :(", style: UIAlertActionStyle.Default, handler: { action in
                self.completeExtension()
            }))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        } else {
            // Get the access token from shared defaults
            self.sharedDefaults?.synchronize()
            
            // Load in access token to make posts
            if let accessToken = self.sharedDefaults?.objectForKey(self.configurationApiAccessToken) as? NSString {
                
                // Check what we're going to post
                if let url = self.postUrl {
                    // Got a url, post a bookmark
                    self.postBookmark(self.contentText as String, url: url, token: accessToken)
                } else if let text = self.postText {
                    // Got text
                    self.postWire(text, token: accessToken)
                } else if (self.postImages.count != 0) {
                    // Got images
                    self.postImages(self.postImages, description: self.contentText, token: accessToken)
                }
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
        let endpoint = self.spotApiUrl! + method
        
        var post_parameters = [
            "title": title,
            "url": url.URLString,
            "api_key": self.spotApiKey!,
            "auth_token": token
        ]
        
        
        // Success/Error messages
        var message: String = ""
        var title: String = ""
        
        Alamofire.request(.POST, endpoint, parameters: post_parameters, encoding: .URL)
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
        let endpoint = self.spotApiUrl! + method
        
        var post_parameters = [
            "text": text,
            "api_key": self.spotApiKey!,
            "auth_token": token
        ]
        
        // Success/Error messages
        var message: String = ""
        var title: String = ""
        
        Alamofire.request(.POST, endpoint, parameters: post_parameters, encoding: .URL)
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
    
    // Post photos/images
    func postImages(images: [NSURL], description: String, token: NSString) -> Void {
        let method = "photos.post"
        let endpoint = self.spotApiUrl! + method
        
        // Spot uses a timestamp to identify a batch before it's created
        var batchInt: Int = Int(NSDate().timeIntervalSince1970)
        var batch: String = "\(batchInt)"
        
        var post_parameters = [
            "batch": batch,
            "album": "0", // @TODO, need to include this parameter because Elgg.
            "description": description,
            "api_key": self.spotApiKey!,
            "auth_token": token as String
        ]
        
        // Dispatch group for multiple uploads
        let uploadDispatch = dispatch_group_create()
        
        var uploadError: NSError!
        

        for image in images {
    
            dispatch_group_enter(uploadDispatch)
            let urlRequest = photoUploadRequestWithComponents(endpoint, parameters: post_parameters, image: image)
            
            Alamofire.upload(urlRequest.0, urlRequest.1)
                .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                    println("\(totalBytesWritten) / \(totalBytesExpectedToWrite)")
                }
                .responseJSON { (request, response, JSON, error) in
                    
                    if let error = error {
                        uploadError = error
                    }
                    
                    println(request)
                    println(response)
                    println(JSON)
                    println(error)

                    dispatch_group_leave(uploadDispatch)
            }
        }
        
        dispatch_group_notify(uploadDispatch, dispatch_get_main_queue()) {
            println("Requests complete.")
            
            if (uploadError != nil) {
                let alertController = UIAlertController(title: "Uh-oh", message:
                    uploadError?.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
                
                alertController.addAction(UIAlertAction(title: "Ok :(", style: UIAlertActionStyle.Default, handler: { action in
                    self.completeExtension()
                }))
                
            } else {
                let method = "photos.finalize.post"
                let endpoint = self.spotApiUrl! + method
                
                var post_parameters = [
                    "batch": batch,
                    "api_key": self.spotApiKey!,
                    "auth_token": token
                ]
                
                // Success/Error messages
                var message: String = ""
                var title: String = ""
                
                Alamofire.request(.POST, endpoint, parameters: post_parameters, encoding: .URL)
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
    }
    
    // This function creates the required URLRequestConvertible and NSData we need to use Alamofire.upload (modified from: http://stackoverflow.com/questions/26121827/uploading-file-with-parameters-using-alamofire/26747857#26747857 )
    func photoUploadRequestWithComponents(urlString:String, parameters:Dictionary<String, String>, image: NSURL) -> (URLRequestConvertible, NSData) {
        
        // create url request to send
        var mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: urlString)!)
        mutableURLRequest.HTTPMethod = Alamofire.Method.POST.rawValue
        let boundaryConstant = "spotconnect-image-boundary";
        let contentType = "multipart/form-data;boundary="+boundaryConstant
        mutableURLRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // create upload data to send
        let uploadData = NSMutableData()
        
        var contentLength: Int = 0

        if let imageData = NSData(contentsOfURL: image) {
            // Resolve data about this image
            let fileExt: String = image.pathExtension!
            let filePrefix: String = image.lastPathComponent!.stringByDeletingPathExtension
            let filename = "\(filePrefix).\(fileExt)"
            contentLength = imageData.length
    
            // add image
            uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Type: image/\(fileExt)\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData(imageData)
        }
        
        // add parameters
        for (key, value) in parameters {
            uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)".dataUsingEncoding(NSUTF8StringEncoding)!)
        }
        uploadData.appendData("\r\n--\(boundaryConstant)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

        // return URLRequestConvertible and NSData
        return (Alamofire.ParameterEncoding.URL.encode(mutableURLRequest, parameters: nil).0, uploadData)
    }

}
