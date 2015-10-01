//
//  SpotApi.swift
//  SpotConnect
//
//  Created by Jeff Tilson on 2015-05-11.
//  Copyright (c) 2015 Jeff Tilson. All rights reserved.
//

import Foundation
import Alamofire

// Configuration key struct
struct SpotConfig {
    static var configurationManagedKey: String = "com.apple.configuration.managed"
    static var configurationApiEndpoint: String = "apiEndpoint"
    static var configurationApiKey: String = "apiKey"
    static var configurationGoogleClientId: String = "googleClientId"
    static var configurationApiAccessToken: String = "apiAccessToken"
    static var configurationApiEncoding: String = "apiEncoding"
}

struct SpotMethods {
    static var userGetProfile: String = "user.get_profile"
    static var authGetGoogleToken: String = "auth.get_google_auth_token"
    static var authGetToken: String = "auth.get_user_pass_auth_token"
    static var utilPing: String = "util.ping"
    static var bookmarkPost: String = "bookmark.post"
    static var thewirePost: String = "thewire.post"
    static var photosPost: String = "photos.post"
    static var photosFinalizePost: String = "photos.finalize.post"
    static var albumsList: String = "albums.list"
}

class SpotApi {
    var apiConfig = [String: String]()
    var encoding: Alamofire.ParameterEncoding
    
    // Main initializer, pulls data from managed config or local config plist
    init() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        // Try loading the managed app config which is provided by the MDM
        if let managedConfig: NSDictionary = userDefaults.dictionaryForKey(SpotConfig.configurationManagedKey) {
            print("Status VC: Got managed config")
            print(managedConfig)
            
            self.apiConfig[SpotConfig.configurationApiEndpoint] = managedConfig.objectForKey(SpotConfig.configurationApiEndpoint) as? String
            
            self.apiConfig[SpotConfig.configurationApiKey] = managedConfig.objectForKey(SpotConfig.configurationApiKey) as? String

            self.apiConfig[SpotConfig.configurationGoogleClientId] = managedConfig.objectForKey(SpotConfig.configurationGoogleClientId) as? String
            
        }
        
//        // Nope.. fall back to local plist (DEV ONLY!!!)
//        if let path = NSBundle.mainBundle().pathForResource("AppConfig", ofType: "plist") {
//            if let localConfig = NSDictionary(contentsOfFile: path) {
//                print("Login VC: Fallback to  local config")
//                print(localConfig)
//                self.apiConfig[SpotConfig.configurationApiKey] = localConfig.objectForKey(SpotConfig.configurationApiKey) as? String
//                self.apiConfig[SpotConfig.configurationApiEndpoint] = localConfig.objectForKey(SpotConfig.configurationApiEndpoint) as? String
//                self.apiConfig[SpotConfig.configurationGoogleClientId] = localConfig.objectForKey(SpotConfig.configurationGoogleClientId) as? String
//            }
//        }
        
        // Set default encoding
        self.encoding = .URL
    }
    
    // Init with api keys/values
    init(apiKey: String, apiEndpoint: String, apiAccessToken: String) {
        
        self.apiConfig[SpotConfig.configurationApiKey] = apiKey
        self.apiConfig[SpotConfig.configurationApiEndpoint] = apiEndpoint
        self.apiConfig[SpotConfig.configurationApiAccessToken] = apiAccessToken
        
        self.encoding = .URL
    }
    
    // Set api request encoding
    func setEncoding(encoding: Alamofire.ParameterEncoding) {
        self.encoding = encoding
    }
    
    // Set the api access token
    func setAccessToken(token: String) -> Void {
        self.apiConfig[SpotConfig.configurationApiAccessToken] = token
    }
    
    // Convenience function to execute a get request
    func makeGetRequest(call: NSString, parameters: [String: AnyObject]?, completion: (Response<AnyObject, NSError>)
        -> Void) {
            self.makeRequest(.GET, call: call, parameters: parameters, completion: completion)
    }
    
    // Convenience function to execute a post request
    func makePostRequest(call: NSString, parameters: [String: AnyObject]?, completion: (Response<AnyObject, NSError>)
        -> Void) {
            self.makeRequest(.POST, call: call, parameters: parameters, completion: completion)
    }
    
    // Make a generic request with givem parameters
    func makeRequest(method: Alamofire.Method, call: NSString, parameters: [String : AnyObject]?, completion: (Response<AnyObject, NSError>)
 -> Void) {

        var apiParameters = self.getApiParameters()
    
        // Check if we've got extra parameters
        if let params = parameters {
            // Yep, merge 'em
            apiParameters.merge(params)
        }
    
        print(apiParameters)

        let endpoint = self.apiConfig[SpotConfig.configurationApiEndpoint]! + (call as String)
        
        Alamofire.request(method, endpoint, parameters: apiParameters, encoding: self.encoding)
            .responseJSON{ response in
                // This is probably less than correct.. but.
                completion(response)
        }
    
    }
    
    // Perform an upload with url request
    func uploadWithUrlRequest(urlRequest: (URLRequestConvertible, NSData), completion: (Response<AnyObject, NSError>)
        -> Void) {
            
        Alamofire.upload(urlRequest.0, data: urlRequest.1)
            .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                print("\(totalBytesWritten) / \(totalBytesExpectedToWrite)")
            }
            .responseJSON { response in
                completion(response)
            }
        
    }
    
    // This function creates the required URLRequestConvertible and NSData we 
    // need to use Alamofire.upload 
    // Modified from: http://stackoverflow.com/questions/26121827/uploading-file-with-parameters-using-alamofire/26747857#26747857
    func photoUploadRequestWithComponents(call:String, parameters:[String: String]?, image: NSURL) -> (URLRequestConvertible, NSData) {
        
        // Build endpoint
        let urlString = self.getConfigValueForKey(SpotConfig.configurationApiEndpoint)! + (call as String)
        
        var apiParameters = self.getApiParameters()
        
        if let params = parameters {
            apiParameters.merge(params)
        }
        
        // create url request to send
        let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: urlString)!)
        mutableURLRequest.HTTPMethod = Alamofire.Method.POST.rawValue
        let boundaryConstant = "spotconnect-image-boundary";
        let contentType = "multipart/form-data;boundary="+boundaryConstant
        mutableURLRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // create upload data to send
        let uploadData = NSMutableData()
        
        if let imageData = NSData(contentsOfURL: image) {
            // Resolve data about this image
            let fileExt: String = image.pathExtension!
            let filePrefix: String = (image.lastPathComponent! as NSString).stringByDeletingPathExtension
            let filename = "\(filePrefix).\(fileExt)"
            
            // add image
            uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Type: image/\(fileExt)\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData(imageData)
        }
        
        // add parameters
        for (key, value) in apiParameters {
            uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)".dataUsingEncoding(NSUTF8StringEncoding)!)
        }
        uploadData.appendData("\r\n--\(boundaryConstant)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        // return URLRequestConvertible and NSData
        return (Alamofire.ParameterEncoding.URL.encode(mutableURLRequest, parameters: nil).0, uploadData)
    }

    // Get config value for given key
    func getConfigValueForKey(key: String) -> String? {
        if let value: String = self.apiConfig[key] {
            return value
        } else {
            return nil
        }
    }
    
    // Build general api parameters
    private func getApiParameters() -> [String: String] {
        var apiParameters = [
            "api_key": self.apiConfig[SpotConfig.configurationApiKey]!
        ]
        
        // Include the access token if it's set already
        if let accessToken = self.getConfigValueForKey(SpotConfig.configurationApiAccessToken) {
            apiParameters["auth_token"] = accessToken
        }
        
        return apiParameters
    }
}

// Dictionary extension to allow easy merging
extension Dictionary {
    mutating func merge<K, V>(dict: [K: V]){
        for (k, v) in dict {
            self.updateValue(v as! Value, forKey: k as! Key)
        }
    }
}