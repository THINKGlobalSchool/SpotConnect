//
//  HelpViewController.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-05-14.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import UIKit
import AVKit
import Foundation
import AVFoundation

class HelpViewController: UIViewController {
    // MARK: - Outlets
    
    @IBOutlet weak var signin: SpotHelpButton!
    @IBOutlet weak var bookmark: SpotHelpButton!
    @IBOutlet weak var photo: SpotHelpButton!
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.twoColorLayerGradient(SpotColors.LIGHTRED, colorTwo: SpotColors.DARKRED)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // Provide the corresponding video name in the button tag
        signin.videoTitle = "signin_final"
        signin.videoType = "mov"
        
        bookmark.videoTitle = "bookmark_final"
        bookmark.videoType = "mov"
        
        photo.videoTitle = "photo_final"
        photo.videoType = "mov"
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Make sure we were sent here with a help button
        if let helpButton: SpotHelpButton = sender as? SpotHelpButton {
            let destination = segue.destinationViewController as! AVPlayerViewController
            
            let url = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource(helpButton.videoTitle, ofType: helpButton.videoType)!)

            destination.player = AVPlayer(URL: url)
            destination.videoGravity = AVLayerVideoGravityResizeAspectFill
        }
    }
    
    // MARK: - Actions
    
    @IBAction func helpButtonPressed(sender: SpotHelpButton) {
        performSegueWithIdentifier("playVideo", sender: sender)
    }
  

}
