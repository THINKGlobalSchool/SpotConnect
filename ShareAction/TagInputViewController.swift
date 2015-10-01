//
//  TagInputViewController.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-09-29.
//  Copyright © 2015 Jeff Tilson. All rights reserved.
//

import UIKit

protocol TagInputViewControllerDelegate {
    func tagInputCompleted(textValue: String)
}

class TagInputViewController: UIViewController, UINavigationControllerDelegate, TLTagsControlDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tagInput: TLTagsControl!
    
    // MARK: - Class constants/vars
    var delegate: TagInputViewControllerDelegate?
    var initialTagString: String?
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationController?.delegate = self
        
        // Set initial tags if available
        if let tagString = self.initialTagString {
            if (!tagString.isEmpty) {
                let tagArray = tagString.componentsSeparatedByString(", ")
                self.tagInput.tags = NSMutableArray(array: tagArray)
                self.tagInput.reloadTagSubviews()
            }
        }

        self.tagInput.tapDelegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UINavigationControllerDelegate
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        if (!viewController.isKindOfClass(object_getClass(self))) {
            
            // Convert tags array to a string
            if let array = self.tagInput.tags as NSArray as? [String] {
                let imploded = array.joinWithSeparator(", ")
                self.delegate?.tagInputCompleted(imploded)
            }
        }
    }
    
    // MARK: - TLTagsControlDelegate
    func tagsControl(tagsControl: TLTagsControl!, tappedAtIndex index: Int) {
        // Handle tap events for tags
    }
}
