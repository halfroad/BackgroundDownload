//
//  BackgroundDownloadService.swift
//  SportsTracer
//
//  Created by Li, Jin Hui on 2020/8/3.
//  Copyright © 2020 HalfRoad Software Inc. All rights reserved.
//

import UIKit

/*
 Usage:
 
 let backgroundDownloadService = BackgroundDownloadService.createInstance()
 
 backgroundDownloadService.start(from: url, HTTPHeaderFields) { (result, location, url, error) in
    // File downloaded
 })
 
 */
class BackgroundDownloadService: NSObject, URLSessionDownloadDelegate {
    
    static let DEFAULT_TIMEOUT: TimeInterval = 60 * 10

    private lazy var urlSession: URLSession = {
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.halfroad.interview.sportstracer_\(NSUUID().uuidString)")
        
        //config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.timeoutIntervalForRequest = BackgroundDownloadService.DEFAULT_TIMEOUT
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var completionHandler: ((Bool, _ location: URL?, _ url: URL?, _ error: Error?) -> Void)?
    private var allTasksCompletionHandler: (( _ urlSession: URLSession?) -> Void)?
    
    private override init() {
        
        // Avoiding the authentification problem when the device is locked.
        
        if let plist = Bundle.main.path(forResource: "Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: plist) as? [String: AnyObject],
            var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first,
            let bundle = dict["CFBundleIdentifier"] {
            path.append("/Caches/com.apple.nsurlsessiond/Downloads/\(bundle)")
            
            try? FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: path)
        }
    }
    
    class func createInstance() -> BackgroundDownloadService {
        
        return BackgroundDownloadService()
    }
    
    override func copy() -> Any {
        
        return self
    }
    
    override func mutableCopy() -> Any {
    
        return self
    }
}

extension BackgroundDownloadService {
    
    func start (from url: String, _ headerFields: [String: String]?, _ completionHandler: @escaping ((Bool, _ location: URL?, _ url: URL?, _ error: Error?) -> Void)) -> Void {
        
        if let requestURL = URL (string: url) {
            
            var reuquest = URLRequest (url: requestURL)
            if let headerFields = headerFields {
                reuquest.allHTTPHeaderFields = headerFields
            }
            
            reuquest.timeoutInterval = BackgroundDownloadService.DEFAULT_TIMEOUT
            reuquest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            self.completionHandler = completionHandler
            let downloadTask = self.urlSession.downloadTask(with: reuquest)
            
            downloadTask.resume()
            
            //self.urlSession.finishTasksAndInvalidate()
        }
    }
    
    func create (from url: String, _ completionHandler: @escaping ((Bool, _ location: URL?, _ url: URL?, _ error: Error?) -> Void)) -> URLSessionDownloadTask? {
        
        self.create(from: url, nil, completionHandler)
    }
    
    func create (from url: String, _ headerFields: [String: String]?, _ completionHandler: @escaping ((Bool, _ location: URL?, _ url: URL?, _ error: Error?) -> Void)) -> URLSessionDownloadTask? {
        
        if let requestURL = URL (string: url) {
            
            var reuquest = URLRequest (url: requestURL)
            if let headerFields = headerFields {
                reuquest.allHTTPHeaderFields = headerFields
            }
            
            reuquest.timeoutInterval = BackgroundDownloadService.DEFAULT_TIMEOUT
            reuquest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            self.completionHandler = completionHandler
            let downloadTask = self.urlSession.downloadTask(with: reuquest)
            
            //self.urlSession.finishTasksAndInvalidate()
            
            return downloadTask
        }
        
        return nil
    }
    
    func cancel() -> Void {
        
        self.urlSession.invalidateAndCancel()
    }
}

extension BackgroundDownloadService {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let handler = self.completionHandler {
            handler(true, location, downloadTask.currentRequest?.url, nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        if let handler = self.completionHandler, let error = error {
            handler(false, nil, task.currentRequest?.url, error)
        }
    }
    
    /*
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
        print("Resume at fileOffset: \(fileOffset)")
    }
     
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("didWriteData: totalBytesExpectedToWrite: \(totalBytesExpectedToWrite), totalBytesWritten: \(totalBytesWritten), bytesWritten: \(bytesWritten)")
    }
 */
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                let backgroundCompletionHandler =
                appDelegate.backgroundCompletionHandler else {
                    return
            }
            
            if let handler = self.allTasksCompletionHandler {
                handler(session)
            }
            
            backgroundCompletionHandler()
        }
    }
}

extension BackgroundDownloadService {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        SSLPinning.shared.handleChallenge(session, challenge, completionHandler)
    }
}
