//
//  SSLPining.swift
//  SportsTracer
//
//  Created by Li, Jin Hui on 2020/8/3.
//  Copyright © 2020 HalfRoad Software Inc. All rights reserved.
//

import UIKit

class SSLPinning: NSObject {
        
    static let shared = SSLPinning()
    
    func handleChallenge (_ session: URLSession, _ challenge: URLAuthenticationChallenge, _ completionHandler: ((_ disposition: URLSession.AuthChallengeDisposition, _ credential: URLCredential) -> Void)?) -> Void {
        
        var disposition = URLSession.AuthChallengeDisposition.performDefaultHandling
        var credential: URLCredential = URLCredential()
        
        switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    if self.checkTrust(serverTrust, challenge.protectionSpace.host) {
                        credential = URLCredential(trust: serverTrust)
                        disposition = .useCredential
                    }
            }
            
            default:
            print("Default")
        }
        
        if let handler = completionHandler {
            handler(disposition, credential)
        }
    }
}

extension SSLPinning {
    
    private func findCertificates() -> [NSData] {
        
        let paths = Bundle.main.paths(forResourcesOfType: "cer", inDirectory: ".")
        var certificates = [NSData]()
        
        for path in paths {
            
            let url = URL(fileURLWithPath: path)
            
            if let data = NSData(contentsOf: url) {
                certificates.append(data)
            }
        }
        
        return certificates
    }
    
    private func checkTrust (_ trust: SecTrust, _ domain: String) -> Bool {
        
        var policies = [SecPolicy]()
        
        policies.append(SecPolicyCreateSSL(true, domain as CFString))
        
        SecTrustSetPolicies(trust, policies as CFTypeRef)
        
        let lcoalCerfiticates = self.findCertificates()
        var pinnedCerfiticates = [SecCertificate]()
        
        for certificateData in lcoalCerfiticates {
            if let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) {
                pinnedCerfiticates.append(certificate)
            }
        }
        
        SecTrustSetAnchorCertificates(trust, pinnedCerfiticates as CFArray)
        
        var error: CFError?
        let result = SecTrustEvaluateWithError(trust, &error)
        
        if result {
            
            let serverCertificates = self.trustChain(trust: trust)
            
            for trustChainCertificate in serverCertificates.reversed() {
                if lcoalCerfiticates.contains(trustChainCertificate) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func trustChain (trust: SecTrust) -> [CFData] {
        
        let count = SecTrustGetCertificateCount(trust)
        var chain = [CFData]()
        
        for i in 0...count - 1 {
            if let certificate = SecTrustGetCertificateAtIndex(trust, i) {
               chain.append(SecCertificateCopyData(certificate))
            }
        }
        
        return chain
    }
}
