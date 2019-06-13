//
//  Manager+AnyAuthenticationChallengeResponder.swift
//  FisherKit
//
//  Created by Courtland Bueno on 3/8/19.
//

import Foundation


extension FisherKitManager {
    
    open class AnyAuthenticationChallengeResponder: AuthenticationChallengeResponsable {
        
        typealias SessionLevelImp = (Downloader, URLAuthenticationChallenge, @escaping AuthenticationChallengeCompletion) -> Void
        
        typealias TaskLevelImp = (Downloader, URLSessionTask, URLAuthenticationChallenge, @escaping AuthenticationChallengeCompletion) -> Void
        
        private let _sessionLevelImp: SessionLevelImp
        private let _taskLevelImp: TaskLevelImp
        
        private init(sessionLevelResponder: @escaping SessionLevelImp, taskLevelChallengeResponder: @escaping  TaskLevelImp) {
            self._sessionLevelImp = sessionLevelResponder
            self._taskLevelImp = taskLevelChallengeResponder
        }
        
        init<Responder: AuthenticationChallengeResponsable>(_ responder: Responder) where Responder.Item == Item {
            self._sessionLevelImp = responder.downloader
            self._taskLevelImp = responder.downloader
        }
        
        convenience init() {
            self.init(sessionLevelResponder: {_,_,completion in
                completion(.performDefaultHandling, nil)
            }) { (_, _, _, completion) in
                completion(.performDefaultHandling, nil)
            }
            
        }
        
        public func downloader(_ downloader: FisherKitManager.Downloader, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            _sessionLevelImp(downloader, challenge, completionHandler)
        }
        
        public func downloader(_ downloader: FisherKitManager.Downloader, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            _taskLevelImp(downloader, task, challenge, completionHandler)
        }
    }
}
