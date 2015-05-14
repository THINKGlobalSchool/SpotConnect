//
//  StatusViewController.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-04-16.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import UIKit
import AddressBook
import SystemConfiguration
import Alamofire
import SwiftyJSON

class StatusViewController: UIViewController {
    
    // MARK: - Outlets
    // User info elements
    @IBOutlet weak var spotUserPicture: UIImageView!
    @IBOutlet weak var spotUserName: UILabel!
    @IBOutlet weak var spotUserEmail: UILabel!
    
    // User info container (UIView)
    @IBOutlet weak var spotUserInfoContainer: UIView!
    
    // MARK: - Class constants/vars
    // Defaults
    let sharedDefaults = NSUserDefaults(suiteName: "group.thinkglobalschool.ExtensionSharingDefaults")
    let userDefaults = NSUserDefaults.standardUserDefaults()

    // Image cache
    var imageCache = [String:UIImage]()
    
    // User info cache
    var infoCache = [String:String]()
    
    let spotApi = SpotApi()
    
    // MARK: UIViewController    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.twoColorLayerGradient(SpotColors.LIGHTRED, colorTwo: SpotColors.DARKRED)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
       
        // Make sure we've got the api key and endpoint
        if let apiKey: String = spotApi.getConfigValueForKey(SpotConfig.configurationApiKey), apiEndpoint: String = spotApi.getConfigValueForKey(SpotConfig.configurationApiEndpoint) {
            
            // This is sucky.. copying the key and url into the shared defaults so the
            // share extension can access them
            self.sharedDefaults?.setObject(apiKey, forKey: SpotConfig.configurationApiKey)
            self.sharedDefaults?.setObject(apiEndpoint, forKey: SpotConfig.configurationApiEndpoint)
            self.sharedDefaults?.synchronize()
            
            // Store in keychain
            let (spotAuthDictionary, spotDictionaryError) = Locksmith.loadDataForUserAccount("spotUser")
            
            // Check for stored user/token info
            if (spotDictionaryError == nil && spotAuthDictionary != nil) {
                if let accessToken = spotAuthDictionary?[SpotConfig.configurationApiAccessToken] as? NSString {
                    // Store the access token as well in the shared defaults
                    self.sharedDefaults?.setObject(accessToken, forKey: SpotConfig.configurationApiAccessToken)
                    self.sharedDefaults?.synchronize()
                    
                    // Set access token on api instance
                    self.spotApi.setAccessToken(accessToken as String)
                    
                    // Populate user info
                    spotApiGetUserProfile()
                } else {
                    // Dictionary exists, but there is no matching key, show login
                    performSegueWithIdentifier("ShowLoginSegue", sender: self)
                }
            } else {
                // No info! Segue to the login page
                performSegueWithIdentifier("ShowLoginSegue", sender: self)
            }
            
        } else {
            self.showMessage("Error", message: "One or more configuration values is unavailable")
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // Do stuff before the view appears
    }
    
    
    // MARK: - IBAction
    @IBAction func unwindToStatus(segue: UIStoryboardSegue) {
        // Called when coming back from the login view controller (not used.. yet)
    }

    @IBAction func spotSignOutAction(sender: UIButton) {
        // Delete the stored user token
        let error = Locksmith.deleteDataForUserAccount("spotUser")
        
        // Check for error saving keychain data
        if (error == nil) {
            // Clear out the user defaults data as well
            self.sharedDefaults?.removeObjectForKey(SpotConfig.configurationApiAccessToken)
            self.sharedDefaults?.synchronize()
            
            // Clear the caches
            self.imageCache["userPicture"] = nil
            self.infoCache["userName"] = nil
            self.infoCache["userEmail"] = nil
            self.infoCache["userUsername"] = nil

            // Ok, access token removed. Show login again
            performSegueWithIdentifier("ShowLoginSignoutSegue", sender: self)
        } else {
            if let kError = error {
                self.showMessage(kError.localizedDescription,dismiss: "Dismiss",message: kError.localizedFailureReason!)
            }
        }
    }
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "ShowLoginSignoutSegue") {
            // Set sign out flag to perform additional tasks on sign out
            var loginViewController: LoginViewController = segue.destinationViewController as! LoginViewController
            loginViewController.didSignOut = true
        }
    }
    
    // MARK: - Helpers
    /**
     * Load Spot user data from the API
     */
    func spotApiGetUserProfile() -> Void {
        if let auth_token = self.sharedDefaults?.stringForKey(SpotConfig.configurationApiAccessToken) {
            
            spotApi.makeGetRequest(SpotMethods.userGetProfile, parameters: nil) {
                (request, response, data, error) in
                
                if (error == nil) {
                    
                    var json = JSON(data!)
                    
                    // Check status
                    if (json["status"] >= 0) {
                        let username = json["result"]["username"]
                        let name = json["result"]["name"]
                        let email = json["result"]["email"]
                        let picture = json["result"]["picture"]
                        
                        self.spotRefreshUserProfile(json["result"])
                    } else {
                        self.showMessage("Error", dismiss: "Dismiss", message: json["message"].stringValue)
                    }
                    
                }
            }
       }
    }
    
    /**
     * Update the spot user profile elements
     */
    func spotRefreshUserProfile(json: JSON) -> Void {
        // Cache values
        if let userEmail = self.infoCache["userEMail"], userName = self.infoCache["userName"], userUsername = self.infoCache["userUsername"] {
            self.spotUserName.text = userName
            self.spotUserEmail.text = userEmail
        } else {
            // Not cached, throw em in
            self.infoCache["userEmail"] = json["email"].stringValue
            self.infoCache["userName"] = json["name"].stringValue
            self.infoCache["userUsername"] = json["username"].stringValue
            
            self.spotUserName.text = self.infoCache["userName"]
            self.spotUserEmail.text =  self.infoCache["userEmail"]
        }
        
        // Check our image cache and see if we have the picture downloaded/cached
        if let img = imageCache["userPicture"] {
            self.spotUserPicture.image = img
        } else {
            let picture = json["picture"]
            
            // The image isn't cached, download the img data
            // We should perform this in a background thread
            let request: NSURLRequest = NSURLRequest(URL: NSURL(string: picture.stringValue)!)
            let mainQueue = NSOperationQueue.mainQueue()

            NSURLConnection.sendAsynchronousRequest(request, queue: mainQueue, completionHandler: { (response, data, error) -> Void in
                if error == nil {
                    // Convert the downloaded data in to a UIImage object
                    let image = UIImage(data: data)
                    // Store the image in to our cache
                    self.imageCache["userPicture"] = image
                    // Update the cell
                    dispatch_async(dispatch_get_main_queue(), {
                        self.spotUserPicture.image = image
                    })
                }
                else {
                    println("Error: \(error.localizedDescription)")
                }
            })
        }
        
        
    }
}
