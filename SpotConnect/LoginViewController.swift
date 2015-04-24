//
//  LoginViewController.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-03-27.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import UIKit
import AddressBook
import SystemConfiguration
import Alamofire
import SwiftyJSON


class LoginViewController: UIViewController, GIDSignInDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var signInButton: GIDSignInButton!
    
    @IBOutlet weak var spotUsername: UITextField!
    
    @IBOutlet weak var spotPassword: UITextField!
    
    @IBOutlet weak var spotSignIn: UIButton!
    
    // MARK: - Class constants/vars
    var signIn: GIDSignIn?
    
    var didSignOut = false // Can be set by status view to trigger google sign out

    // Spot API constants    
    let spotApiKey = NSUserDefaults.standardUserDefaults().stringForKey("api_key_preference")!
    let spotApiUrl = NSUserDefaults.standardUserDefaults().stringForKey("api_endpoint_preference")!

    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up Google Sign In
        signIn = GIDSignIn.sharedInstance()
        signIn?.clientID = "96486200889-cnkki5c8stmbctbn2p3mvv8s1no4qicp.apps.googleusercontent.com"
        signIn?.shouldFetchBasicProfile = true
        signIn?.delegate = self
        
        // Customize the Google Button
        self.signInButton.style = GIDSignInButtonStyle.Standard
        self.signInButton.colorScheme = GIDSignInButtonColorScheme.Dark
        
        // Check if we're returning here from a sign out
        if (self.didSignOut) {
            self.didSignOut = false
            
            // Force google disconnect
            signIn?.disconnect()
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - GIDSignInDelegate Protocol
    func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        // Check for error
        if (error == nil) {
            // Called when we're signed in
            println("Signed In")
            spotApiGetGoogleToken()
        } else {
            println(error)
            // Cancelled?
        }
    }
    
    func signIn(signIn: GIDSignIn!, didDisconnectWithUser user: GIDGoogleUser!, withError error: NSError!) {
        println("Signed Out")
    }
    
    func spotApiGetGoogleToken() {
        // Get access token from Spot
        var endpoint = spotApiUrl + "auth.get_google_auth_token"
        
        if let userEmail = self.signIn?.currentUser.profile.email {
            var parameters = [
                "email": userEmail,
                "api_key": spotApiKey
            ]
            
            Alamofire.request(.POST, endpoint, parameters: parameters, encoding: .URL)
                .responseJSON{ (request, response, data, error) in
                    var json = JSON(data!)
                    
                    // Check status
                    if (json["status"] >= 0) {
                        // Successful login, save access token in the keychaing
                        let error = Locksmith.saveData(["spot_access_token": json["result"].stringValue], forUserAccount: "spotUser")
                        
                        // Check for error saving keychain data
                        if (error == nil) {
                            // Good to go, back to status viewcontroller
                            self.performSegueWithIdentifier("unwindToStatusSegue", sender: self)
                        } else {
                            if let kError = error {
                                if let reason = kError.localizedFailureReason {
                                    self.showMessage(kError.localizedDescription,dismiss: "Dismiss",message: reason)
                                }
                            }
                        }
                    } else {
                        self.showMessage("Error", dismiss: "Dismiss", message: json["message"].stringValue)
                        self.signIn?.disconnect() // Disconnect the user that just authorized
                    }
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func spotSignInAction(sender: UIButton) {
        println("Spot sign in pressed")
        
        // Lets try signing in..
        let endpoint = spotApiUrl + "auth.get_user_pass_auth_token"

        let parameters = [
            "username": self.spotUsername.text,
            "password": self.spotPassword.text,
            "api_key": spotApiKey
        ]

        Alamofire.request(.POST, endpoint, parameters: parameters, encoding: .URL)
            .responseJSON{ (request, response, data, error) in
                if (error == nil) {
                    var json = JSON(data!)
                    // Check status
                    if (json["status"] >= 0) {
                        // Successful login, save access token in the keychaing
                        let error = Locksmith.saveData(["spot_access_token": json["result"].stringValue], forUserAccount: "spotUser")
                    
                        // Check for error saving keychain data
                        if (error == nil) {
                        // Good to go, back to status viewcontroller
                            self.performSegueWithIdentifier("unwindToStatusSegue", sender: self)
                        } else {
                            if let kError = error {
                                self.showMessage(kError.localizedDescription,dismiss: "Dismiss",message: kError.localizedFailureReason!)
                            }
                        }
                    } else {
                        self.showMessage("Error", dismiss: "Dismiss", message: json["message"].stringValue)
                    }
                }
            }
    }
}

