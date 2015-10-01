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

class ShareViewController: SLComposeServiceViewController, TagInputViewControllerDelegate, AlbumListViewControllerDelegate {
    
    // MARK: - Class constants/vars
    var spotApi: SpotApi!
    
    let sharedDefaults = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")
    
    var postContentLoaded: Bool = false

    // Items that can be shared
    var postUrl: NSURL?
    var postText: String?
    var postError: NSError?
    var postImages: [NSURL] = []
    
    // Add additional items
    var postTags: SLComposeSheetConfigurationItem!
    var postAlbum: SLComposeSheetConfigurationItem!
    var postAlbumGuid: String!
    
    // MARK: - SLComposeServiceViewController
    
    // Perform tasks when the view is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.hidden = true

        // Get item provider
        let item : NSExtensionItem = self.extensionContext?.inputItems.first as! NSExtensionItem
        
        // Process attachments from item provider
        for provider in item.attachments! {
            let itemProvider = provider as! NSItemProvider
            self.setPostContent(itemProvider)
        }

        // Check for access token
        if let accessToken = self.sharedDefaults?.objectForKey(SpotConfig.configurationApiAccessToken) as? NSString {
            
            // Create an API instance
            spotApi = SpotApi(
                apiKey: NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")!.stringForKey(SpotConfig.configurationApiKey)!,
                apiEndpoint: NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")!.stringForKey(SpotConfig.configurationApiEndpoint)!,
                apiAccessToken: accessToken as String
            )
            
            // Good, got a token. Let's check if we can talk to the server
            print("Attempting ping..")
            
            spotApi.makeGetRequest(SpotMethods.utilPing, parameters: nil) {
                (response) in
                
                if (response.result.isFailure) {
                    if let uError = response.result.error {
                        // Ok, had an error
                        if let errorCode = uError.code as Int? {
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

    // Adds additonal configuration items
    override func configurationItems() -> [AnyObject]! {
        // Add configuration items based on content being shared
        if (self.postImages.count >= 1) {
            
            self.postTags = SLComposeSheetConfigurationItem()
            self.postAlbum = SLComposeSheetConfigurationItem()
            
            postTags.title = "Tags"
            postTags.value = ""
            
            postAlbum.title = "Album"
            postAlbum.value = "Mobile Uploads"
            
            postTags.tapHandler = {() -> Void in
                let tagInput: TagInputViewController = self.storyboard?.instantiateViewControllerWithIdentifier("tagInputVC") as! TagInputViewController
                tagInput.delegate = self
                tagInput.initialTagString = self.postTags.value
                
                self.pushConfigurationViewController(tagInput)
            }
            
            postAlbum.tapHandler = {() -> Void in
                let albumInput: AlbumListViewController = AlbumListViewController(style: UITableViewStyle.Plain)
                albumInput.delegate = self
                albumInput.spotApi = self.spotApi
                self.pushConfigurationViewController(albumInput)
            }
            
            return [self.postTags, self.postAlbum]
        } else {
            return []
        }
    }
    
    // Do validation of contentText and/or NSExtensionContext attachments here
    override func isContentValid() -> Bool {
        return true
    }

    /**
      * Set the post content based on content type
      */
    func setPostContent(itemProvider: NSItemProvider) -> Void {
        print("setPostContent")
        // Need to figure out what we're going to be posting, this is in decending order of importance
        let validTypes = [
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

            if let accessToken = spotApi.getConfigValueForKey(SpotConfig.configurationApiAccessToken) {
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
            
            
            // Create and add the view to the screen.
            self.showProgressHUD("Posting")
        }
    }
    
    // MARK: - TagInputViewControllerDelegate
    
    // Set the postTags value to the the string returned by the tag input view controller
    func tagInputCompleted(textValue: String) {
        self.postTags.value = textValue
    }
    
    // MARK: - AlbumListViewControllerDelegate
    func albumInputCompleted(titleString: String, guidString: String) {
        self.popConfigurationViewController()
        self.postAlbum.value = titleString
        self.postAlbumGuid = guidString
    }
    
    // MARK: - Helpers
    
    // Complete extension
    func completeExtension() -> Void {
        self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
    }
    
    // Post a bookmark
    func postBookmark(title: String, url: NSURL, token: NSString) -> Void {
        let post_parameters = [
            "title": title,
            "url": url.URLString,
        ]
        
        // Success/Error messages
        var message: String = ""
        var title: String = ""
        
        spotApi.makePostRequest(SpotMethods.bookmarkPost, parameters: post_parameters) {
            (response) in
            
            // Check for an error first
            if (response.result.isFailure) {
                if let uError = response.result.error {
                    title = uError.localizedDescription
                    
                    if let reason = uError.localizedFailureReason {
                        message = reason
                    } else {
                        message = title
                        title = "Error"
                    }
                }
            } else {
                let json = JSON(response.result.value!)
                
                // Check for an API error
                if (json["status"] >= 0) {
                    // good.. show success
                    title = "Success!"
                    message = "Posted to Spot!"
                } else {
                    title = "Error"
                    message = json["message"].stringValue

                }

                self.hideProgressHUD()
                
                let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                    self.completeExtension()
                }))
                
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // Make a wire post
    func postWire(text: String, token: NSString) -> Void {
        
        let post_parameters = [
            "text": text
        ]
        
        // Success/Error messages
        var message: String = ""
        var title: String = ""
        
        spotApi.makePostRequest(SpotMethods.thewirePost, parameters: post_parameters) {
            (response) in
                // Check for errors
                if (response.result.isFailure) {
                    if let uError = response.result.error {
                        title = uError.localizedDescription
                        
                        if let reason = uError.localizedFailureReason {
                            message = reason
                        } else {
                            message = title
                            title = "Error"
                        }
                    }
                } else {
                    var json = JSON(response.result.value!)
                    
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
            
                self.hideProgressHUD()
            
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
        // Spot uses a timestamp to identify a batch before it's created
        let batchDate = NSDate().timeIntervalSince1970
        let batch: String = "\(batchDate)"
        
        var albumGuid = "0"
        
        // Check and see if we've selected an album guid
        if let selectedAlbumGuid = self.postAlbumGuid {
            albumGuid = selectedAlbumGuid
        }
        
        let post_parameters = [
            "batch": batch,
            "album": albumGuid,
            "description": description,
            "tags": self.postTags.value!
        ]
        
        // Dispatch group for multiple uploads
        let uploadDispatch = dispatch_group_create()
        
        var uploadError: NSError!

        for image in images {
    
            dispatch_group_enter(uploadDispatch)

            let urlRequest = spotApi.photoUploadRequestWithComponents(SpotMethods.photosPost, parameters: post_parameters, image: image)
            
            spotApi.uploadWithUrlRequest(urlRequest) {
                (response) in
                    if let error = response.result.error {
                        uploadError = error
                    }
                
                    print(response.result.value)

                    dispatch_group_leave(uploadDispatch)
            }
        }
        
        dispatch_group_notify(uploadDispatch, dispatch_get_main_queue()) {
            print("Requests complete.")
            
            if (uploadError != nil) {
                let alertController = UIAlertController(title: "Uh-oh", message:
                    uploadError?.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                    self.completeExtension()
                }))
                
                self.presentViewController(alertController, animated: true, completion: nil)
                
            } else {

                let post_parameters = [
                    "batch": batch,
                    "album": albumGuid
                ]
                
                // Success/Error messages
                var message: String = ""
                var title: String = ""
                
                self.spotApi.makePostRequest(SpotMethods.photosFinalizePost, parameters: post_parameters) {
                    (response) in
                        // Check for errors
                        if (response.result.isFailure) {
                            if let uError = response.result.error {
                                title = uError.localizedDescription
                                
                                if let reason = uError.localizedFailureReason {
                                    message = reason
                                } else {
                                    message = title
                                    title = "Error"
                                }
                            }
                        } else {
                            var json = JSON(response.result.value!)
                            
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
                    
                        self.hideProgressHUD()
                
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
}
