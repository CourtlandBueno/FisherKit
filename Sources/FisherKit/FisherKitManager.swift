//
//  FisherKitManager.swift
//  FisherKit
//
//  Created by Wei Wang on 15/4/6.
//
//  Copyright (c) 2019 Wei Wang <courtland.bueno@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import Foundation

public protocol FisherKitItemType: CacheCostCalculable, FisherKitCompatible {
    static var itemTypeDescription: String { get }
}

extension FisherKitItemType {
    public var cacheCost: Int {
        return 0
    }
}

public protocol ItemBound {
    associatedtype Item: FisherKitItemType
    
    static var itemType: Item.Type { get }
}

extension ItemBound {
    public static var itemType: Item.Type {
        return Item.self
    }
}

/// The downloading progress block type.
/// The parameter value is the `receivedSize` of current response.
/// The second parameter is the total expected data length from response's "Content-Length" header.
/// If the expected length is not available, this block will not be called.
public typealias DownloadProgressBlock = ((_ receivedSize: Int64, _ totalSize: Int64) -> Void)

/// Main manager class of FisherKit. It connects FisherKit downloader and cache,
/// to provide a set of convenience methods to use FisherKit for tasks.
/// You can use this class to retrieve an item via a specified URL from web or cache.
public final class FisherKitManager<Item: FisherKitItemType>: ItemBound {
    
    
    /// Represents the result of a FisherKit retrieving item task.
    public struct RetrievalSuccess {
        
        /// Gets the item object of this result.
        public let item: Item
        
        /// Gets the cache source of the item. It indicates from which layer of cache this item is retrieved.
        /// If the item is just downloaded from network, `.none` will be returned.
        public let cacheType: CacheType
        
        /// The `Source` from which the retrieve task begins.
        public let source: Source
    }
    
            
    /// Represents a shared manager used across FisherKit.
    /// Use this instance for getting or storing items with FisherKit.
    public static var `default`: FisherKitManager<Item> {
        return .init(downloader: .default, cache: .default)
    }
    
    // Mark: Public Properties
    /// The `ItemCache` used by this manager. It is `ItemCache.default` by default.
    /// If a cache is specified in `FisherKitManager.defaultOptions`, the value in `defaultOptions` will be
    /// used instead.
    public var cache: Cache
    
    /// The `Downloader` used by this manager. It is `Downloader.default` by default.
    /// If a downloader is specified in `FisherKitManager.defaultOptions`, the value in `defaultOptions` will be
    /// used instead.
    public var downloader: Downloader
    
    /// Default options used by the manager. This option will be used in
    /// FisherKit manager related methods, as well as all view extension methods.
    /// You can also passing other options for each item task by sending an `options` parameter
    /// to FisherKit's APIs. The per item options will overwrite the default ones,
    /// if the option exists in both.
    public var defaultOptions: Option.OptionsInfo = .empty
    
    // Use `defaultOptions` to overwrite the `downloader` and `cache`.
    private var currentDefaultOptions: Option.OptionsInfo {
        return [.downloader(downloader), .targetCache(cache)] + defaultOptions
    }

    private let processingQueue: CallbackQueue
   
    
    init(downloader: Downloader, cache: Cache) {
        self.downloader = downloader
        self.cache = cache
        
        let processQueueName = "com.courtlandbueno.FisherKit.Manager.processQueue.\(UUID().uuidString)"
        processingQueue = .dispatch(DispatchQueue(label: processQueueName))
    }
    
    
    // Mark: Getting Items

    /// Gets an item from a given resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object defines data information like key or URL.
    ///   - options: Options to use when creating the animated item.
    ///   - progressBlock: Called when the item downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called. `progressBlock` is always called in
    ///                    main queue.
    ///   - completionHandler: Called when the item retrieved and set finished. This completion handler will be invoked
    ///                        from the `options.callbackQueue`. If not specified, the main queue will be used.
    /// - Returns: A task represents the item downloading. If there is a download task starts for `.network` resource,
    ///            the started `DownloadTask` is returned. Otherwise, `nil` is returned.
    ///
    /// - Note:
    ///    This method will first check whether the requested `resource` is already in cache or not. If cached,
    ///    it returns `nil` and invoke the `completionHandler` after the cached item retrieved. Otherwise, it
    ///    will download the `resource`, store it in cache, then call `completionHandler`.
    ///
    @discardableResult
    public func retrieve(
        with resource: ResourceType,
        options: Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrievalSuccess, Error>) -> Void)?) -> FisherKitManager.DownloadTask?
    {
        let source = Source.network(resource)
        
        let task = retrieve(with: source,
                        options: options,
                        progressBlock: progressBlock,
                        completionHandler: completionHandler
        )
        return task
    }

    /// Gets an item from a given resource.
    ///
    /// - Parameters:
    ///   - source: The `Source` object defines data information from network or a data provider.
    ///   - options: Options to use when creating the animated item.
    ///   - progressBlock: Called when the item downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called. `progressBlock` is always called in
    ///                    main queue.
    ///   - completionHandler: Called when the item retrieved and set finished. This completion handler will be invoked
    ///                        from the `options.callbackQueue`. If not specified, the main queue will be used.
    /// - Returns: A task represents the
    ///item downloading. If there is a download task starts for `.network` resource,
    ///            the started `DownloadTask` is returned. Otherwise, `nil` is returned.
    ///
    /// - Note:
    ///    This method will first check whether the requested `source` is already in cache or not. If cached,
    ///    it returns `nil` and invoke the `completionHandler` after the cached item retrieved. Otherwise, it
    ///    will try to load the `source`, store it in cache, then call `completionHandler`.
    ///
    public func retrieve(
        with source: Source,
        options: Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrievalSuccess, Error>) -> Void)?) -> FisherKitManager.DownloadTask?
    {
        let options = currentDefaultOptions + (options ?? .empty)
        return retrieve(
            with: source,
            options: Option.ParsedOptionsInfo(options),
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }
    
    func retrieve(
        with source: Source,
        options: Option.ParsedOptionsInfo,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrievalSuccess, Error>) -> Void)?) -> FisherKitManager.DownloadTask?
    {
        if options.forceRefresh {
            return loadAndCache(
                source: source, options: options, progressBlock: progressBlock, completionHandler: completionHandler)?.value
        } else {
            let loadedFromCache = retrieveFromCache(
                source: source,
                options: options,
                completionHandler: completionHandler)
            
            if loadedFromCache {
                return nil
            }
            
            if options.onlyFromCache {
                let error = Error.cacheError(reason: .itemNotExisting(key: source.cacheKey))
                completionHandler?(.failure(error))
                return nil
            }
            
            return loadAndCache(
                source: source, options: options, progressBlock: progressBlock, completionHandler: completionHandler)?.value
        }
    }

    func provide(
        provider: DataProvider,
        options: Option.ParsedOptionsInfo,
        completionHandler: ((Result<LoadingSuccess, Error>) -> Void)?)
    {
        guard let  completionHandler = completionHandler else { return }
        provider.data { result in
            switch result {
            case .success(let data):
                (options.processingQueue ?? self.processingQueue).execute {
                    let processor = options.processor
                    let processingItem = ProcessItem.data(data)
                    guard let item = processor.process(item: processingItem, options: options) else {
                        options.callbackQueue.execute {
                            
                            let error = Error.processorError(
                                reason: .processingFailed(processor: processor, item: processingItem))
                            completionHandler(.failure(error))
                        }
                        return
                    }

                    options.callbackQueue.execute {
                        let result = LoadingSuccess(item: item, url: nil, originalData: data)
                        completionHandler(.success(result))
                    }
                }
            case .failure(let error):
                options.callbackQueue.execute {
                    let error = Error.itemSettingError(
                        reason: .dataProviderError(provider: provider, error: error))
                    completionHandler(.failure(error))
                }

            }
        }
    }

    @discardableResult
    func loadAndCache(
        source: Source,
        options: Option.ParsedOptionsInfo,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrievalSuccess, Error>) -> Void)?) -> FisherKitManager.DownloadTask.WrappedTask?
    {
        func cacheItem(_ result: Result<LoadingSuccess, Error>)
        {
            switch result {
            case .success(let value):
                // Add item to cache.
                let targetCache = options.targetCache ?? self.cache
                targetCache.store(
                    value.item,
                    original: value.originalData,
                    forKey: source.cacheKey,
                    options: options,
                    toDisk: !options.cacheMemoryOnly)
                {
                    _ in
                    if options.waitForCache {
                        let result = RetrievalSuccess(item: value.item, cacheType: .none, source: source)
                        completionHandler?(.success(result))
                    }
                }

                // Add original item to cache if necessary.
                let needToCacheOriginalItem = options.cacheOriginalItem &&
                    options.processor != Processor.default
                if needToCacheOriginalItem {
                    let originalCache = options.originalCache ?? targetCache
                    originalCache.storeToDisk(
                        value.originalData,
                        forKey: source.cacheKey,
                        processorIdentifier: Processor.default.identifier,
                        expiration: options.diskCacheExpiration)
                }

                if !options.waitForCache {
                    let result = RetrievalSuccess(item: value.item, cacheType: .none, source: source)
                    completionHandler?(.success(result))
                }
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }

        switch source {
        case .network(let resource):
            let downloader = options.downloader ?? self.downloader
            guard let task = downloader.downloadItem(
                with: resource.downloadURL,
                options: options,
                progressBlock: progressBlock,
                completionHandler: cacheItem) else {
                return nil
            }
            return .download(task)
        case .provider(let provider):
            provide(provider: provider, options: options, completionHandler: cacheItem)
            return .dataProviding
        }
    }
    
    /// Retrieves item from memory or disk cache.
    ///
    /// - Parameters:
    ///   - source: The target source from which to get item.
    ///   - key: The key to use when caching the item.
    ///   - url: Item request URL. This is not used when retrieving item from cache. It is just used for
    ///          `RetrieveItemResult` callback compatibility.
    ///   - options: Options on how to get the item from item cache.
    ///   - completionHandler: Called when the item retrieving finishes, either with succeeded
    ///                        `RetrieveItemResult` or an error.
    /// - Returns: `true` if the requested item or the original item before being processed is existing in cache.
    ///            Otherwise, this method returns `false`.
    ///
    /// - Note:
    ///    The item retrieving could happen in either memory cache or disk cache. The `.processor` option in
    ///    `options` will be considered when searching in the cache. If no processed item is found, FisherKit
    ///    will try to check whether an original version of that item is existing or not. If there is already an
    ///    original, FisherKit retrieves it from cache and processes it. Then, the processed item will be store
    ///    back to cache for later use.
    func retrieveFromCache(
        source: Source,
        options: Option.ParsedOptionsInfo,
        completionHandler: ((Result<RetrievalSuccess, Error>) -> Void)?) -> Bool
    {
        // 1. Check whether the item was already in target cache. If so, just get it.
        let targetCache = options.targetCache ?? cache
        let key = source.cacheKey
        let targetItemCached = targetCache.cachedType(
            forKey: key, processorIdentifier: options.processor.identifier)
        
        let validCache = targetItemCached.cached &&
            (options.fromMemoryCacheOrRefresh == false || targetItemCached == .memory)
        if validCache {
            targetCache.retrieve(forKey: key, options: options) { result in
                guard let completionHandler = completionHandler else { return }
                options.callbackQueue.execute {
                    result.match(
                        onSuccess: { cacheResult in
                            let value: Result<RetrievalSuccess, Error>
                            if let item = cacheResult.item {
                                value = result.map {
                                    RetrievalSuccess(item: item, cacheType: $0.cacheType, source: source)
                                }
                            } else {
                                value = .failure(Error.cacheError(reason: .itemNotExisting(key: key)))
                            }
                            completionHandler(value)
                    },
                        onFailure: { _ in
                            completionHandler(.failure(Error.cacheError(reason: .itemNotExisting(key: key))))
                    })
                }
            }
            return true
        }

        // 2. Check whether the original item exists. If so, get it, process it, save to storage and return.
        let originalCache = options.originalCache ?? targetCache
        // No need to store the same file in the same cache again.
        if originalCache === targetCache && options.processor == Processor.default {
            return false
        }

        // Check whether the unprocessed item existing or not.
        let originalItemCached = originalCache.cachedType(
            forKey: key, processorIdentifier: Processor.default.identifier).cached
        if originalItemCached {
            // Now we are ready to get found the original item from cache. We need the unprocessed item, so remove
            // any processor from options first.
            var optionsWithoutProcessor = options
            optionsWithoutProcessor.processor = Processor.default
            originalCache.retrieve(forKey: key, options: optionsWithoutProcessor) { result in
                
                result.match(
                    onSuccess: { cacheResult in
                        guard let item = cacheResult.item else {
                            return
                        }
                        
                        let processor = options.processor
                        (options.processingQueue ?? self.processingQueue).execute {
                            let item = ProcessItem.item(item)
                            guard let processedItem = processor.process(item: item, options: options) else {
                                let error = Error.processorError(
                                    reason: .processingFailed(processor: processor, item: item))
                                options.callbackQueue.execute { completionHandler?(.failure(error)) }
                                return
                            }
                            
                            var cacheOptions = options
                            cacheOptions.callbackQueue = .untouch
                            targetCache.store(
                                processedItem,
                                forKey: key,
                                options: cacheOptions,
                                toDisk: !options.cacheMemoryOnly)
                            {
                                _ in
                                if options.waitForCache {
                                    let value = RetrievalSuccess(item: processedItem, cacheType: .none, source: source)
                                    options.callbackQueue.execute { completionHandler?(.success(value)) }
                                }
                            }
                            
                            if !options.waitForCache {
                                let value = RetrievalSuccess(item: processedItem, cacheType: .none, source: source)
                                options.callbackQueue.execute { completionHandler?(.success(value)) }
                            }
                        }
                }, onFailure: { _ in
                    options.callbackQueue.execute {
                        completionHandler?(.failure(Error.cacheError(reason: .itemNotExisting(key: key))))
                    }
                })
            }
            return true
        }

        return false

    }
}

extension FisherKitManager where Item: Codable {
    public convenience init(encoder: String = "PropertyListEncoder", decoder: String = "PropertyListDecoder") {
        self.init(downloader: .default, cache: .default)
        self.defaultOptions = [
            .processor(FisherKitManager.defaultProcessor),
            .cacheSerializer(FisherKitManager.defaultSerializer),
            .dataProcessingInfo(["encoder": encoder, "decoder" : decoder])
        ]
        
    }
}

extension FisherKitManager where Item == Image {
    public convenience init() {
        self.init(downloader: .default, cache: .default)
        
        self.defaultOptions += [
            .processor(FisherKitManager.defaultProcessor),
            .cacheSerializer(FisherKitManager.defaultSerializer)
        ]
    }
}
