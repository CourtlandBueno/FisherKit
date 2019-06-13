//
//  Manager+Downloader.swift
//  FisherKit-MacOS
//
//  Created by Courtland Bueno on 3/6/19.
//

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension FisherKitManager {
    
    /// Represents a success result of an item downloading progress.
    public struct LoadingSuccess {
        
        /// The downloaded item.
        public let item: Item
        
        /// Original URL of the item request.
        public let url: URL?
        
        /// The raw data received from downloader.
        public let originalData: Data
    }
    
    /// Represents a task of an item downloading process.
    public struct DownloadTask {
        
        /// The `SessionDataTask` object bounded to this download task. Multiple `DownloadTask`s could refer
        /// to a same `sessionTask`. This is an optimization in FisherKit to prevent multiple downloading task
        /// for the same URL resource at the same time.
        ///
        /// When you `cancel` a `DownloadTask`, this `SessionDataTask` and its cancel token will be pass through.
        /// You can use them to identify the cancelled task.
        public let sessionTask: SessionDataTask
        
        /// The cancel token which is used to cancel the task. This is only for identify the task when it is cancelled.
        /// To cancel a `DownloadTask`, use `cancel` instead.
        public let cancelToken: SessionDataTask.CancelToken
        
        /// Cancel this task if it is running. It will do nothing if this task is not running.
        ///
        /// - Note:
        /// In FisherKit, there is an optimization to prevent starting another download task if the target URL is being
        /// downloading. However, even when internally no new session task created, a `DownloadTask` will be still created
        /// and returned when you call related methods, but it will share the session downloading task with a previous task.
        /// In this case, if multiple `DownloadTask`s share a single session download task, cancelling a `DownloadTask`
        /// does not affect other `DownloadTask`s.
        ///
        /// If you need to cancel all `DownloadTask`s of a url, use `Downloader.cancel(url:)`. If you need to cancel
        /// all downloading tasks of an `Downloader`, use `Downloader.cancelAll()`.
        public func cancel() {
            sessionTask.cancel(token: cancelToken)
        }
        
        enum WrappedTask {
            case download(DownloadTask)
            case dataProviding
            
            func cancel() {
                switch self {
                case .download(let task): task.cancel()
                case .dataProviding: break
                }
            }
            
            var value: DownloadTask? {
                switch self {
                case .download(let task): return task
                case .dataProviding: return nil
                }
            }
        }
    }
    
}


extension FisherKitManager {
    
    /// Represents a downloading manager for requesting the item with a URL from server.
    open class Downloader {
    
        // MARK: Singleton
        /// The default downloader.
        public static var `default`: Downloader {
            return .init(name: "default")
        }
        
        // MARK: Public Properties
        /// The duration before the downloading is timeout. Default is 15 seconds.
        open var downloadTimeout: TimeInterval = 15.0
        
        /// A set of trusted hosts when receiving server trust challenges. A challenge with host name contained in this
        /// set will be ignored. You can use this set to specify the self-signed site. It only will be used if you don't
        /// specify the `authenticationChallengeResponder`.
        ///
        /// If `authenticationChallengeResponder` is set, this property will be ignored and the implementation of
        /// `authenticationChallengeResponder` will be used instead.
        open var trustedHosts: Set<String>?
        
        /// Use this to set supply a configuration for the downloader. By default,
        /// NSURLSessionConfiguration.ephemeralSessionConfiguration() will be used.
        ///
        /// You could change the configuration before a downloading task starts.
        /// A configuration without persistent storage for caches is requested for downloader working correctly.
        open var sessionConfiguration = URLSessionConfiguration.ephemeral {
            didSet {
                session.invalidateAndCancel()
                session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
            }
        }
        
        /// Whether the download requests should use pipeline or not. Default is false.
        open var requestsUsePipelining = false
        
        /// Delegate of this `Downloader` object. See `DownloaderDelegate` protocol for more.
        open weak var delegate: AnyDownloaderDelegate?
        
        
        
        /// A responder for authentication challenge.
        /// Downloader will forward the received authentication challenge for the downloading session to this responder.
        open weak var authenticationChallengeResponder: AnyAuthenticationChallengeResponder?
        
        private lazy var reflectiveChallengeResponder = AnyAuthenticationChallengeResponder(self)
        private lazy var reflectiveDownloadDelegate = AnyDownloaderDelegate(self)
        
        private let name: String
        private let sessionDelegate: SessionDelegate
        private var session: URLSession
        
        // MARK: Initializers
        
        /// Creates a downloader with name.
        ///
        /// - Parameter name: The name for the downloader. It should not be empty.
        
        public init (name: String) {
            if name.isEmpty {
                fatalError("[FisherKit] You should specify a name for the downloader. "
                    + "A downloader with empty name is not permitted.")
            }
            
            self.name = name
            
            self.sessionDelegate = SessionDelegate()
            self.session = URLSession(
                configuration: sessionConfiguration,
                delegate: sessionDelegate,
                delegateQueue: nil)
            
            authenticationChallengeResponder = reflectiveChallengeResponder
            setupSessionHandler()

        }
        
        deinit { session.invalidateAndCancel() }
        
        private func setupSessionHandler() {
            sessionDelegate.onReceiveSessionChallenge.delegate(on: self, block: { (self, invoke) in
                self.authenticationChallengeResponder?.downloader(self, didReceive: invoke.1, completionHandler: invoke.2)

            })
            sessionDelegate.onReceiveSessionTaskChallenge.delegate(on: self) { (self, invoke) in
                self.authenticationChallengeResponder?.downloader(self, task: invoke.1, didReceive: invoke.2, completionHandler: invoke.3)
            }
            sessionDelegate.onValidStatusCode.delegate(on: self) { (self, code) in
                return (self.delegate ?? self.reflectiveDownloadDelegate).isValidStatusCode(code, for: self)
            }
            sessionDelegate.onDownloadingFinished.delegate(on: self) { (self, value) in
                let (url, result) = value
                do {
                    let value = try result.get()
                    self.delegate?.downloader(self, didFinishDownloadingItemForURL: url, with: value, error: nil)
                } catch {
                    self.delegate?.downloader(self, didFinishDownloadingItemForURL: url, with: nil, error: error)
                }
            }
            sessionDelegate.onDidDownloadData.delegate(on: self) { (self, task) in
                guard let url = task.task.originalRequest?.url else {
                    return task.mutableData
                }
                if let downloadDelegate = self.delegate {
                    return downloadDelegate.downloader(self, didDownload: task.mutableData, for: url)
                } else {
                    return (self.delegate ?? self.reflectiveDownloadDelegate).downloader(self,
                                                                                         didDownload: task.mutableData,
                                                                                         for: url)
                }
            }
        }
        
        @discardableResult
        func downloadItem(
            with url: URL,
            options: Option.ParsedOptionsInfo,
            progressBlock: DownloadProgressBlock? = nil,
            completionHandler: ((Result<LoadingSuccess, Error>) -> Void)? = nil) -> DownloadTask?
        {
            // Creates default request.
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: downloadTimeout)
            request.httpShouldUsePipelining = requestsUsePipelining
            
            if let requestModifier = options.requestModifier {
                // Modifies request before sending.
                guard let r = requestModifier.modified(for: request) else {
                    options.callbackQueue.execute {
                        completionHandler?(.failure(Error.requestError(reason: .emptyRequest)))
                    }
                    return nil
                }
                request = r
            }
            
            // There is a possibility that request modifier changed the url to `nil` or empty.
            // In this case, throw an error.
            guard let url = request.url, !url.absoluteString.isEmpty else {
                options.callbackQueue.execute {
                    completionHandler?(.failure(Error.requestError(reason: .invalidURL(request: request))))
                }
                return nil
            }
            
            // Wraps `progressBlock` and `completionHandler` to `onProgress` and `onCompleted` respectively.
            let onProgress = progressBlock.map {
                block -> Delegate<(Int64, Int64), Void> in
                let delegate = Delegate<(Int64, Int64), Void>()
                delegate.delegate(on: self) { (_, progress) in
                    let (downloaded, total) = progress
                    block(downloaded, total)
                }
                return delegate
            }
            
            let onCompleted = completionHandler.map {
                block -> Delegate<Result<LoadingSuccess, Error>, Void> in
                let delegate =  Delegate<Result<LoadingSuccess, Error>, Void>()
                delegate.delegate(on: self) { (_, result) in
                    block(result)
                }
                return delegate
            }
            
            // SessionDataTask.TaskCallback is a wrapper for `onProgress`, `onCompleted` and `options` (for processor info)
            let callback = SessionDataTask.TaskCallback(onProgress: onProgress, onCompleted: onCompleted, options: options)
            
            // Ready to start download. Add it to session task manager (`sessionHandler`)
            
            let downloadTask: DownloadTask
            if let existingTask = sessionDelegate.task(for: url) {
                downloadTask = sessionDelegate.append(existingTask, url: url, callback: callback)
            } else {
                let sessionDataTask = session.dataTask(with: request)
                sessionDataTask.priority = options.downloadPriority
                downloadTask = sessionDelegate.add(sessionDataTask, url: url, callback: callback)
            }
            
            let sessionTask = downloadTask.sessionTask
            // Start the session task if not started yet.
            if !sessionTask.started {
                sessionTask.onTaskDone.delegate(on: self) { (self, done) in
                    // Underlying downloading finishes.
                    // result: Result<(Data, URLResponse?)>, callbacks: [TaskCallback]
                    let (result, callbacks) = done
                    
                    // Before processing the downloaded data.
                    do {
                        let value = try result.get()
                        self.delegate?.downloader(
                            self,
                            didFinishDownloadingItemForURL: url,
                            with: value.1,
                            error: nil)
                    } catch {
                        self.delegate?.downloader(
                            self,
                            didFinishDownloadingItemForURL: url,
                            with: nil,
                            error: error)
                    }
                    
                    switch result {
                    // Download finished. Now process the data to an item.
                    case .success(let (data, response)):
                        
                        let processor = DataProcessor(source: url, data: data, callbacks: callbacks, processingQueue: options.processingQueue)
                        
                        processor.onItemProcessed.delegate(on: self) { (self, result) in
                            // `onItemProcessed` will be called for `callbacks.count` times, with each
                            // `SessionDataTask.TaskCallback` as the input parameter.
                            // result: Result<Item>, callback: SessionDataTask.TaskCallback
                            let (result, callback) = result
                            
                            if let item = try? result.get() {
                                self.delegate?.downloader(self, didDownload: item, for: url, with: response)
                            }
                            
                            let itemResult = result.map { LoadingSuccess(item: $0, url: url, originalData: data) }
                            let queue = callback.options.callbackQueue
                            
                            queue.execute {
                                callback.onCompleted?.call(itemResult)
                                
                            }
                        }
                        processor.process()
                        
                    case .failure(let error):
                        callbacks.forEach { callback in
                            let queue = callback.options.callbackQueue
                            queue.execute {
                                callback.onCompleted?.call(.failure(error))
                                
                            }
                        }
                    }
                }
                delegate?.downloader(self, willDownloadItemForURL: url, with: request)
                sessionTask.resume()
            }
            return downloadTask
        }
        
        // MARK: Dowloading Task
        /// Downloads an item with a URL and option.
        ///
        /// - Parameters:
        ///   - url: Target URL.
        ///   - options: The options could control download behavior. See `FisherKitOptionsInfo`.
        ///   - progressBlock: Called when the download progress updated. This block will be always be called in main queue.
        ///   - completionHandler: Called when the download progress finishes. This block will be called in the queue
        ///                        defined in `.callbackQueue` in `options` parameter.
        /// - Returns: A downloading task. You could call `cancel` on it to stop the download task.
        @discardableResult
        open func downloadItem(
            with url: URL,
            options: Option.OptionsInfo? = nil,
            progressBlock: DownloadProgressBlock? = nil,
            completionHandler: ((Result<LoadingSuccess, Error>) -> Void)? = nil) -> DownloadTask?
        {
            return downloadItem(
                with: url,
                options: Option.ParsedOptionsInfo(options),
                progressBlock: progressBlock,
                completionHandler: completionHandler)
        }
        
        
        // MARK: Cancelling Task
        
        /// Cancel all downloading tasks for this `Downloader`. It will trigger the completion handlers
        /// for all not-yet-finished downloading tasks.
        ///
        /// If you need to only cancel a certain task, call `cancel()` on the `DownloadTask`
        /// returned by the downloading methods. If you need to cancel all `DownloadTask`s of a certain url,
        /// use `Downloader.cancel(url:)`.
        public func cancelAll() {
            sessionDelegate.cancelAll()
        }
        
        /// Cancel all downloading tasks for a given URL. It will trigger the completion handlers for
        /// all not-yet-finished downloading tasks for the URL.
        ///
        /// - Parameter url: The URL which you want to cancel downloading.
        public func cancel(url: URL) {
            sessionDelegate.cancel(url: url)
        }



    }
}

//MARK: - AuthenticationChallengeResponsable
extension FisherKitManager.Downloader: AuthenticationChallengeResponsable {
    public func downloader(
        _ downloader: Downloader,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trustedHosts = downloader.trustedHosts, trustedHosts.contains(challenge.protectionSpace.host) {
                let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
    
    public func downloader(
        _ downloader: Downloader,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        completionHandler(.performDefaultHandling, nil)
    }
}

//MARK: - Downloader Delegate
extension FisherKitManager.Downloader: DownloaderDelegate {
    
    public func downloader(
        _ downloader: Downloader,
        willDownloadItemForURL url: URL,
        with request: URLRequest?) {
        
    }
    
    public func downloader(
        _ downloader: Downloader,
        didFinishDownloadingItemForURL url: URL,
        with response: URLResponse?,
        error: Swift.Error?) {
    }
    
    public func downloader(
        _ downloader: Downloader,
        didDownload item: Item,
        for url: URL,
        with response: URLResponse?) {
    }
    
    public func isValidStatusCode(_ code: Int, for downloader: Downloader) -> Bool {
        return (200..<400).contains(code)
    }
    public func downloader(_ downloader: Downloader, didDownload data: Data, for url: URL) -> Data? {
        return data
    }
}
