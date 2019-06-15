//
//  Manager+Prefetcher.swift
//  FisherKit
//
//  Created by Courtland Bueno on 3/6/19.
//

import Foundation
/// Progress update block of prefetcher.
///
/// - `skippedResources`: An array of resources that are already cached before the prefetching starting.
/// - `failedResources`: An array of resources that fail to be downloaded. It could because of being cancelled while
///                      downloading, encountered an error when downloading or the download not being started at all.
/// - `completedResources`: An array of resources that are downloaded and cached successfully.
public typealias PrefetcherProgressBlock =
    ((_ skippedResources: [ResourceType], _ failedResources: [ResourceType], _ completedResources: [ResourceType]) -> Void)


public typealias PrefetcherSourceProgressBlock =
    ((_ skippedSources: [Source], _ failedSources: [Source], _ completedSources: [Source]) -> Void)
/// Completion block of prefetcher.
///
/// - `skippedResources`: An array of resources that are already cached before the prefetching starting.
/// - `failedResources`: An array of resources that fail to be downloaded. It could because of being cancelled while
///                      downloading, encountered an error when downloading or the download not being started at all.
/// - `completedResources`: An array of resources that are downloaded and cached successfully.
public typealias PrefetcherCompletionHandler =
    ((_ skippedResources: [ResourceType], _ failedResources: [ResourceType], _ completedResources: [ResourceType]) -> Void)

public typealias PrefetcherSourceCompletionHandler =
    ((_ skippedSources: [Source], _ failedSources: [Source], _ completedSources: [Source]) -> Void)

fileprivate let requestingQueue = DispatchQueue(label: identifierPrefix + "Prefetcher.requestingQueue")

extension FisherKitManager {
    /// `ItemPrefetcher` represents a downloading manager for requesting many items via URLs, then caching them.
    /// This is useful when you know a list of item resources and want to download them before showing. It also works with
    /// some Cocoa prefetching mechanism like table view or collection view `prefetchDataSource`, to start item downloading
    /// and caching before they display on screen.
    public class Prefetcher: CustomStringConvertible {
        
        
        public var description: String {
            return "\(Unmanaged.passUnretained(self).toOpaque())"
        }
        /// The maximum concurrent downloads to use when prefetching items. Default is 5.
        public var maxConcurrentDownloads = 5


        private let prefetchSources: [Source]
        private let options: Option.ParsedOptionsInfo

        private var progressBlock: PrefetcherProgressBlock?
        private var completionHandler: PrefetcherCompletionHandler?
        
        private var progressSourceBlock: PrefetcherSourceProgressBlock?
        private var completionSourceHandler: PrefetcherSourceCompletionHandler?
        
        private var tasks = [String: DownloadTask.WrappedTask]()

        private var pendingSources: ArraySlice<Source>
        private var skippedSources = [Source]()
        private var completedSources = [Source]()
        private var failedSources = [Source]()

        private var stopped = false

        // A manager used for prefetching. We will use the helper methods in manager.
        private let manager: FisherKitManager<Item>
        
        private let pretchQueue = DispatchQueue(label: identifierPrefix + "Prefetcher.pretchQueue")
        
        
        private var finished: Bool {
            let totalFinished: Int = failedSources.count + skippedSources.count + completedSources.count
            return totalFinished == prefetchSources.count && tasks.isEmpty
        }

        /// Creates an item prefetcher with an array of URLs.
        ///
        /// The prefetcher should be initiated with a list of prefetching targets. The URLs list is immutable.
        /// After you get a valid `ItemPrefetcher` object, you call `start()` on it to begin the prefetching process.
        /// The items which are already cached will be skipped without downloading again.
        ///
        /// - Parameters:
        ///   - urls: The URLs which should be prefetched.
        ///   - options: A dictionary could control some behaviors. See `FisherKitOptionsInfo` for more.
        ///   - progressBlock: Called every time an resource is downloaded, skipped or cancelled.
        ///   - completionHandler: Called when the whole prefetching process finished.
        ///
        /// - Note:
        /// By default, the `Downloader.defaultDownloader` and `Cache<Item>.defaultCache` will be used as
        /// the downloader and cache target respectively. You can specify another downloader or cache by using
        /// a customized `FisherKitOptionsInfo`. Both the progress and completion block will be invoked in
        /// main thread. The `.callbackQueue` value in `optionsInfo` will be ignored in this method.

        public convenience init(urls: [URL],
                                options: Option.OptionsInfo? = nil,
                                progressBlock: PrefetcherProgressBlock? = nil,
                                completionHandler: PrefetcherCompletionHandler? = nil)
        {
            let resources: [ResourceType] = urls.map { $0 }
            self.init(
                resources: resources,
                options: options,
                progressBlock: progressBlock,
                completionHandler: completionHandler)
        }
        
        
        
        /// Creates an item prefetcher with an array of resources.
        ///
        /// - Parameters:
        ///   - resources: The resources which should be prefetched. See `Resource` type for more.
        ///   - options: A dictionary could control some behaviors. See `FisherKitOptionsInfo` for more.
        ///   - progressBlock: Called every time an resource is downloaded, skipped or cancelled.
        ///   - completionHandler: Called when the whole prefetching process finished.
        ///
        /// - Note:
        /// By default, the `Downloader.defaultDownloader` and `Cache<Item>.defaultCache` will be used as
        /// the downloader and cache target respectively. You can specify another downloader or cache by using
        /// a customized `FisherKitOptionsInfo`. Both the progress and completion block will be invoked in
        /// main thread. The `.callbackQueue` value in `optionsInfo` will be ignored in this method.
        public convenience init(
            resources: [ResourceType],
            options: Option.OptionsInfo? = nil,
            progressBlock: PrefetcherProgressBlock? = nil,
            completionHandler: PrefetcherCompletionHandler? = nil) {
            self.init(sources: resources.map({.network($0)}), options: options)
            self.progressBlock = progressBlock
            self.completionHandler = completionHandler
        }

        
        public convenience init(sources: [Source],
                    options: Option.OptionsInfo? = nil,
                    progressBlock: PrefetcherSourceProgressBlock? = nil,
                    completionHandler: PrefetcherSourceCompletionHandler? = nil)
        {
            self.init(sources: sources, options: options)
            self.progressSourceBlock = progressBlock
            self.completionSourceHandler = completionHandler
        }

        internal init(sources: [Source], options: FisherKitManager<Item>.Option.OptionsInfo?) {
            var options = Option.ParsedOptionsInfo(options)
            prefetchSources = sources
            pendingSources = ArraySlice(sources)
            options.callbackQueue = .dispatch(pretchQueue)
            self.options = options
            let cache = self.options.targetCache ?? .default
            let downloader = self.options.downloader ?? .default
            manager = FisherKitManager<Item>(downloader: downloader, cache: cache)
        }
        
        
        /// Starts to download the resources and cache them. This can be useful for background downloading
        /// of assets that are required for later use in an app. This code will not try and update any UI
        /// with the results of the process.
        public func start() {
            pretchQueue.async {
                guard !self.stopped else {
                    assertionFailure("You can not restart the same prefetcher. Try to create a new prefetcher.")
                    self.handleComplete()
                    return
                }
                
                guard self.maxConcurrentDownloads > 0 else {
                    assertionFailure("There should be concurrent downloads value should be at least 1.")
                    self.handleComplete()
                    return
                }
                
                // Empty case.
                guard self.prefetchSources.count > 0 else {
                    self.handleComplete()
                    return
                }
                
                let initialConcurrentDownloads = min(self.prefetchSources.count, self.maxConcurrentDownloads)
                for _ in 0 ..< initialConcurrentDownloads {
                    if let resource = self.pendingSources.popFirst() {
                        self.startPrefetching(resource)
                    }
                }
            }
        }

        /// Stops current downloading progress, and cancel any future prefetching activity that might be occuring.
        public func stop() {
            pretchQueue.async {
                if self.finished { return }
                self.stopped = true
                self.tasks.values.forEach { $0.cancel() }
            }
        }

        private func downloadAndCache(_ source: Source) {

            let downloadTaskCompletionHandler: ((Result<RetrievalSuccess, Error>) -> Void) = { result in
                self.tasks.removeValue(forKey: source.cacheKey)
                do {
                    let _ = try result.get()
                    self.completedSources.append(source)
                } catch {
                    self.failedSources.append(source)
                }

                self.reportProgress()
                if self.stopped {
                    if self.tasks.isEmpty {
                        self.failedSources.append(contentsOf: self.pendingSources)
                        self.handleComplete()
                    }
                } else {
                    self.reportCompletionOrStartNext()
                }
            }
            var downloadTask: DownloadTask.WrappedTask?
            requestingQueue.sync {
                downloadTask = manager.loadAndCache(
                    source: source,
                    options: options,
                    completionHandler: downloadTaskCompletionHandler)
            }
            
            if let downloadTask = downloadTask {
                tasks[source.cacheKey] = downloadTask
            }
        }

        private func append(cached source: Source) {
            skippedSources.append(source)

            reportProgress()
            reportCompletionOrStartNext()
        }

        private func startPrefetching(_ source: Source)
        {
            if options.forceRefresh {
                downloadAndCache(source)
                return
            }

            let cacheType = manager.cache.cachedType(
                forKey: source.cacheKey,
                processorIdentifier: options.processor.identifier)
            switch cacheType {
            case .memory:
                append(cached: source)
            case .disk:
                if options.alsoPrefetchToMemory {
                    _ = manager.retrieveFromCache(
                        source: source,
                        options: options)
                    {
                        _ in
                        self.append(cached: source)
                    }
                } else {
                    append(cached: source)
                }
            case .none:
                downloadAndCache(source)
            }
        }

        private func reportProgress() {
            if progressBlock == nil && progressSourceBlock == nil {
                return
            }
            
            let skipped = self.skippedSources
            let failed = self.failedSources
            let completed = self.completedSources
            CallbackQueue.mainCurrentOrAsync.execute {
                self.progressSourceBlock?(skipped, failed, completed)
                self.progressBlock?(
                    skipped.compactMap { $0.asResource },
                    failed.compactMap { $0.asResource },
                    completed.compactMap { $0.asResource }
                )
            }
        }

        private func reportCompletionOrStartNext() {
            if let resource = self.pendingSources.popFirst() {
                // Loose call stack for huge ammount of sources.
                pretchQueue.async { self.startPrefetching(resource) }
            } else {
                guard allFinished else { return }
                self.handleComplete()
            }
        }
        
        var allFinished: Bool {
            return skippedSources.count + failedSources.count + completedSources.count == prefetchSources.count
        }

        private func handleComplete() {
            if completionHandler == nil && completionSourceHandler == nil {
                return
            }
            // The completion handler should be called on the main thread
            CallbackQueue.mainCurrentOrAsync.execute {
                self.completionSourceHandler?(self.skippedSources, self.failedSources, self.completedSources)
                self.completionHandler?(
                    self.skippedSources.compactMap({$0.asResource}),
                    self.failedSources.compactMap({$0.asResource}),
                    self.completedSources.compactMap({$0.asResource}))
                self.completionHandler = nil
                self.progressBlock = nil
            }
        }
    }
    
}
