//
//  AlbumListViewController.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-09-30.
//  Copyright © 2015 Jeff Tilson. All rights reserved.
//

import UIKit
import SwiftyJSON

// MARK: - Protocols
protocol AlbumListViewControllerDelegate {
    func albumInputCompleted(titleString: String, guidString: String)
}

class AlbumListViewController: UITableViewController {
    
    // MARK: - Class structures
    struct TableViewValues {
        static let identifier = "albumCell"
    }
    
    // MARK: - Class constants/vars
    var delegate: AlbumListViewControllerDelegate?
    var spotApi: SpotApi!
    var albums = [[String: String]]()
    
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: TableViewValues.identifier)
        
        // Load a list of albums
        spotApi.makeGetRequest(SpotMethods.albumsList, parameters: nil) {
            (response) in
            
            var wasError = false
            var title = ""
            var message = ""

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
                    wasError = true
                }
            } else {
                var json = JSON(response.result.value!)
                
                // Check for an API error
                if (json["status"] != 0) {
                    title = "Error"
                    message = json["message"].stringValue
                    wasError = true
                } else {
                    for result in json["result"].arrayValue {
                        
                        let title = result["title"].stringValue
                        let guid = result["guid"].stringValue
                        let album = ["title": title, "guid": guid]
                        self.albums.append(album)
                    }
                    
                    self.tableView.reloadData()
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.tableView.reloadData()
                    })
                }
                
            }
            
            if (wasError) {
                let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: { action in
                    // Pop back to the share view controller
                    self.navigationController?.popViewControllerAnimated(true)
                }))
                
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
        

        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UITableViewController
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
      
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.albums.count
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
        title = "Select Album"
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier(TableViewValues.identifier, forIndexPath: indexPath)
        
        let albumInfo = self.albums[indexPath.row]
        
        cell.textLabel!.text = albumInfo["title"]
        

        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let delegate = self.delegate {
            let selectedAlbum = self.albums[indexPath.row]
            delegate.albumInputCompleted(selectedAlbum["title"]!, guidString: selectedAlbum["guid"]!)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
