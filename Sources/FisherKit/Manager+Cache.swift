//
//  Manager+Cache.swift
//  FisherKit-MacOS
//
//  Created by Courtland Bueno on 3/6/19.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension FisherKitManager.Processor {
    static func temp(identifier: String) -> FisherKitManager.Processor {
        return FisherKitManager.Processor(identifier: identifier, block: {_,_ in return nil})
    }
}


extension FisherKitManager {
    
    /// Represents a hybrid caching system which is composed by a `MemoryStorage.Backend` and a `DiskStorage.Backend`.
    /// `Cache<Item>` is a high level abstract for storing an item as well as its data to disk memory and disk, and
    /// retrieving them back.
    ///
    /// While a default item cache object will be used if you prefer the extension methods of FisherKit, you can create
    /// your own cache object and configure its storages as your need. This class also provide an interface for you to set
    /// the memory and disk storage config.
    open class Cache {
        
        /// Represents the getting item operation from the cache.
        ///
        /// - disk: The item can be retrieved from disk cache.
        /// - memory: The item can be retrieved memory cache.
        /// - none: The item does not exist in the cache.
        public enum CachingSuccess {
            
            /// The item can be retrieved from disk cache.
            case disk(Item)
            
            /// The item can be retrieved memory cache.
            case memory(Item)
            
            /// The item does not exist in the cache.
            case none
            
            /// Extracts the item from cache result. It returns the associated `Item` value for
            /// `.disk` and `.memory` case. For `.none` case, `nil` is returned.
            public var item: Item? {
                switch self {
                case .disk(let item): return item
                case .memory(let item): return item
                case .none: return nil
                }
            }
            
            /// Returns the corresponding `CacheType` value based on the result type of `self`.
            public var cacheType: CacheType {
                switch self {
                case .disk: return .disk
                case .memory: return .memory
                case .none: return .none
                }
            }
        }
        
        /// Represents the caching operation result.
        public struct OperationResults {
            
            /// The cache result for memory cache. Caching an item to memory will never fail.
            public let memoryCacheResult: Result<(), Never>
            
            /// The cache result for disk cache. If an error happens during caching operation,
            /// you can get it from `.failure` case of this `diskCacheResult`.
            public let diskCacheResult: Result<(), Error>
        }
        //    // MARK: Singleton
        //    /// The default `ItemCache` object. FisherKit will use this cache for its related methods if there is no
        //    /// other cache specified. The `name` of this default cache is "default", and you should not use this name
        //    /// for any of your customize cache.
        public static var `default`: Cache {
            let itemDescription = String(reflecting: Item.self)
            return Cache(name: itemDescription + ".default")
        }
        
        // MARK: Public Properties
        /// The `MemoryStorage.Backend` object used in this cache. This storage holds loaded items in memory with a
        /// reasonable expire duration and a maximum memory usage. To modify the configuration of a storage, just set
        /// the storage `config` and its properties.
        public let memoryStorage: MemoryStorage.Backend<Item>
        
        /// The `DiskStorage.Backend` object used in this cache. This storage stores loaded items in disk with a
        /// reasonable expire duration and a maximum disk usage. To modify the configuration of a storage, just set
        /// the storage `config` and its properties.
        public let diskStorage: DiskStorage.Backend<Data>
        
        private let ioQueue: DispatchQueue
        
        /// Closure that defines the disk cache path from a given path and cacheName.
        public typealias DiskCachePathClosure = (URL, String) -> URL
        
        // MARK: Initializers
        
        /// Creates an `Cache<Item>` from a customized `MemoryStorage` and `DiskStorage`.
        ///
        /// - Parameters:
        ///   - memoryStorage: The `MemoryStorage.Backend` object to use in the item cache.
        ///   - diskStorage: The `DiskStorage.Backend` object to use in the item cache.
        public init(
            memoryStorage: MemoryStorage.Backend<Item>,
            diskStorage: DiskStorage.Backend<Data>)
        {
            self.memoryStorage = memoryStorage
            self.diskStorage = diskStorage
            
            
            let ioQueueName = "com.courtlandbueno.FisherKit.Cache.ioQueue.\(UUID().uuidString)"
            ioQueue = DispatchQueue(label: ioQueueName)
            
            let notifications: [(Notification.Name, Selector)]
            #if !os(macOS) && !os(watchOS)
            #if swift(>=4.2)
            notifications = [
                (UIApplication.didReceiveMemoryWarningNotification, #selector(clearMemoryCache)),
                (UIApplication.willTerminateNotification, #selector(cleanExpiredDiskCache)),
                (UIApplication.didEnterBackgroundNotification, #selector(backgroundCleanExpiredDiskCache))
            ]
            #else
            notifications = [
                (NSNotification.Name.UIApplicationDidReceiveMemoryWarning, #selector(clearMemoryCache)),
                (NSNotification.Name.UIApplicationWillTerminate, #selector(cleanExpiredDiskCache)),
                (NSNotification.Name.UIApplicationDidEnterBackground, #selector(backgroundCleanExpiredDiskCache))
            ]
            #endif
            #elseif os(macOS)
            notifications = [
                (NSApplication.willResignActiveNotification, #selector(cleanExpiredDiskCache)),
            ]
            #else
            notifications = []
            #endif
            notifications.forEach {
                NotificationCenter.default.addObserver(self, selector: $0.1, name: $0.0, object: nil)
            }
        }
        
        /// Creates an `Cache<Item>` with a given `name`. Both `MemoryStorage` and `DiskStorage` will be created
        /// with a default config based on the `name`.
        ///
        /// - Parameter name: The name of cache object. It is used to setup disk cache directories and IO queue.
        ///                   You should not use the same `name` for different caches, otherwise, the disk storage would
        ///                   be conflicting to each other. The `name` should not be an empty string.
        public convenience init(name: String) {
            try! self.init(name: name, cacheDirectoryURL: nil, diskCachePathClosure: nil)
        }
        
        /// Creates an `Cache<Item>` with a given `name`, cache directory `path`
        /// and a closure to modify the cache directory.
        ///
        /// - Parameters:
        ///   - name: The name of cache object. It is used to setup disk cache directories and IO queue.
        ///           You should not use the same `name` for different caches, otherwise, the disk storage would
        ///           be conflicting to each other.
        ///   - cacheDirectoryURL: Location of cache directory URL on disk. It will be internally pass to the
        ///                        initializer of `DiskStorage` as the disk cache directory. If `nil`, the cache
        ///                        directory under user domain mask will be used.
        ///   - diskCachePathClosure: Closure that takes in an optional initial path string and generates
        ///                           the final disk cache path. You could use it to fully customize your cache path.
        /// - Throws: An error that happens during item cache creating, such as unable to create a directory at the given
        ///           path.
        public convenience init(
            name: String,
            cacheDirectoryURL: URL?,
            diskCachePathClosure: DiskCachePathClosure? = nil) throws
        {
            if name.isEmpty {
                fatalError("[FisherKit] You should specify a name for the cache. A cache with empty name is not permitted.")
            }
            
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let costLimit = totalMemory / 4
            let memoryStorage = MemoryStorage.Backend<Item>(config:
                .init(totalCostLimit: (costLimit > Int.max) ? Int.max : Int(costLimit)))
            
            var diskConfig = DiskStorage.Config(
                name: name,
                sizeLimit: 0,
                directory: cacheDirectoryURL
            )
            if let closure = diskCachePathClosure {
                diskConfig.cachePathBlock = closure
            }
            let diskStorage = try DiskStorage.Backend<Data>(config: diskConfig)
            diskConfig.cachePathBlock = nil
            
            self.init(memoryStorage: memoryStorage, diskStorage: diskStorage)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: Storing Items
        
        open func store(_ item: Item,
                        original: Data? = nil,
                        forKey key: String,
                        options: Option.ParsedOptionsInfo,
                        toDisk: Bool = true,
                        completionHandler: ((OperationResults) -> Void)? = nil)
        {
            let identifier = options.processor.identifier
            let callbackQueue = options.callbackQueue
            
            let computedKey = key.computedKey(with: identifier)
            // Memory storage should not throw.
            memoryStorage.storeNoThrow(value: item, forKey: computedKey, expiration: options.memoryCacheExpiration)
            
            guard toDisk else {
                if let completionHandler = completionHandler {
                    let result = OperationResults(memoryCacheResult: .success(()), diskCacheResult: .success(()))
                    callbackQueue.execute { completionHandler(result) }
                }
                return
            }
            
            ioQueue.async {
                let serializer = options.cacheSerializer
                if let data = serializer.data(with: item, original: original, options: options) {
                    self.syncStoreToDisk(
                        data,
                        forKey: key,
                        processorIdentifier: identifier,
                        callbackQueue: callbackQueue,
                        expiration: options.diskCacheExpiration,
                        completionHandler: completionHandler)
                } else {
                    guard let completionHandler = completionHandler else { return }
                    
                    
                    let diskError = Error.cacheError(reason: .cannotSerializeItem(item: item, original: original, serializer: serializer))
                    let result = OperationResults(
                        memoryCacheResult: .success(()),
                        diskCacheResult: .failure(diskError))
                    callbackQueue.execute { completionHandler(result) }
                }
            }
        }
        
        
        /// Stores an item to the cache.
        ///
        /// - Parameters:
        ///   - item: The item to be stored.
        ///   - original: The original data of the item. This value will be forwarded to the provided `serializer` for
        ///               further use. By default, FisherKit uses a `DefaultCacheSerializer` to serialize the item to
        ///               data for caching in disk, it checks the item format based on `original` data to determine in
        ///               which item format should be used. For other types of `serializer`, it depends on their
        ///               implementation detail on how to use this original data.
        ///   - key: The key used for caching the item.
        ///   - identifier: The identifier of processor being used for caching. If you are using a processor for the
        ///                 item, pass the identifier of processor to this parameter.
        ///   - serializer: The `CacheSerializerType`
        ///   - toDisk: Whether this item should be cached to disk or not. If `false`, the item is only cached in memory.
        ///             Otherwise, it is cached in both memory storage and disk storage. Default is `true`.
        ///   - callbackQueue: The callback queue on which `completionHandler` is invoked. Default is `.untouch`. For case
        ///                    that `toDisk` is `false`, a `.untouch` queue means `callbackQueue` will be invoked from the
        ///                    caller queue of this method. If `toDisk` is `true`, the `completionHandler` will be called
        ///                    from an internal file IO queue. To change this behavior, specify another `CallbackQueue`
        ///                    value.
        ///   - completionHandler: A closure which is invoked when the cache operation finishes.
        open func store(_ item: Item,
                        original: Data? = nil,
                        forKey key: String,
                        processorIdentifier identifier: String = "",
                        cacheSerializer serializer: Serializer = .default,
                        toDisk: Bool = true,
                        callbackQueue: CallbackQueue = .untouch,
                        completionHandler: ((OperationResults) -> Void)? = nil)
        {
            
            
            let options: Option.ParsedOptionsInfo = Option.ParsedOptionsInfo([
                .processor(Processor.temp(identifier: identifier)),
                .cacheSerializer(serializer),
                .callbackQueue(callbackQueue)
                ])
            store(item, original: original, forKey: key, options: options,
                  toDisk: toDisk, completionHandler: completionHandler)
        }
        
        open func storeToDisk(
            _ data: Data,
            forKey key: String,
            processorIdentifier identifier: String = "",
            expiration: StorageExpiration? = nil,
            callbackQueue: CallbackQueue = .untouch,
            completionHandler: ((OperationResults) -> Void)? = nil)
        {
            ioQueue.async {
                self.syncStoreToDisk(
                    data,
                    forKey: key,
                    processorIdentifier: identifier,
                    callbackQueue: callbackQueue,
                    expiration: expiration,
                    completionHandler: completionHandler)
            }
        }
        
        private func syncStoreToDisk(
            _ data: Data,
            forKey key: String,
            processorIdentifier identifier: String = "",
            callbackQueue: CallbackQueue = .untouch,
            expiration: StorageExpiration? = nil,
            completionHandler: ((OperationResults) -> Void)? = nil)
        {
            let computedKey = key.computedKey(with: identifier)
            let result: OperationResults
            do {
                try self.diskStorage.store(value: data, forKey: computedKey, expiration: expiration)
                result = OperationResults(memoryCacheResult: .success(()), diskCacheResult: .success(()))
            } catch {
                let diskError: Error
                if let error = error as? Error {
                    diskError = error
                } else {
                    diskError = .cacheError(reason: .cannotConvertToData(object: data, error: error))
                }
                
                result = OperationResults(
                    memoryCacheResult: .success(()),
                    diskCacheResult: .failure(diskError)
                )
            }
            if let completionHandler = completionHandler {
                callbackQueue.execute { completionHandler(result) }
            }
        }
        
        // MARK: Removing Items
        
        /// Removes the item for the given key from the cache.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - identifier: The identifier of processor being used for caching. If you are using a processor for the
        ///                 item, pass the identifier of processor to this parameter.
        ///   - fromMemory: Whether this item should be removed from memory storage or not.
        ///                 If `false`, the item won't be removed from the memory storage. Default is `true`.
        ///   - fromDisk: Whether this item should be removed from disk storage or not.
        ///               If `false`, the item won't be removed from the disk storage. Default is `true`.
        ///   - callbackQueue: The callback queue on which `completionHandler` is invoked. Default is `.untouch`.
        ///   - completionHandler: A closure which is invoked when the cache removing operation finishes.
        open func remove(forKey key: String,
                         processorIdentifier identifier: String = "",
                         fromMemory: Bool = true,
                         fromDisk: Bool = true,
                         callbackQueue: CallbackQueue = .untouch,
                         completionHandler: (() -> Void)? = nil)
        {
            let computedKey = key.computedKey(with: identifier)
            
            if fromMemory {
                try? memoryStorage.remove(forKey: computedKey)
            }
            
            if fromDisk {
                ioQueue.async{
                    try? self.diskStorage.remove(forKey: computedKey)
                    if let completionHandler = completionHandler {
                        callbackQueue.execute { completionHandler() }
                    }
                }
            } else {
                if let completionHandler = completionHandler {
                    callbackQueue.execute { completionHandler() }
                }
            }
        }
        
        func retrieve(forKey key: String,
                          options: Option.ParsedOptionsInfo,
                          callbackQueue: CallbackQueue = .untouch,
                          completionHandler: ((Result<CachingSuccess, Error>) -> Void)?)
        {
            // No completion handler. No need to start working and early return.
            guard let completionHandler = completionHandler else { return }
            
            // Try to check the item from memory cache first.
            if let item = retrieveInMemoryCache(forKey: key, options: options) {
                callbackQueue.execute { completionHandler(.success(.memory(item))) }
            } else if options.fromMemoryCacheOrRefresh {
                callbackQueue.execute { completionHandler(.success(.none)) }
            } else {
                // Begin to disk search.
                self.retrieveInDiskCache(forKey: key, options: options, callbackQueue: callbackQueue) {
                    result in
                    // The callback queue is already correct in this closure.
                    switch result {
                    case .success(let item):
                        
                        guard let item = item else {
                            // No item found in disk storage.
                            completionHandler(.success(.none))
                            return
                        }
                        
                        let finalItem = item
                        // Cache the disk item to memory.
                        // We are passing `false` to `toDisk`, the memory cache does not change
                        // callback queue, we can call `completionHandler` without another dispatch.
                        var cacheOptions = options
                        cacheOptions.callbackQueue = .untouch
                        self.store(
                            finalItem,
                            forKey: key,
                            options: cacheOptions,
                            toDisk: false)
                        {
                            _ in
                            completionHandler(.success(.disk(finalItem)))
                        }
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            }
        }
        
        // MARK: Getting Items
        
        /// Gets an item for a given key from the cache, either from memory storage or disk storage.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - options: The `FisherKitOptionsInfo` options setting used for retrieving the item.
        ///   - callbackQueue: The callback queue on which `completionHandler` is invoked. Default is `.untouch`.
        ///   - completionHandler: A closure which is invoked when the item getting operation finishes. If the
        ///                        item retrieving operation finishes without problem, an `ItemCacheResult` value
        ///                        will be sent to this closure as result. Otherwise, a `FisherKitError` result
        ///                        with detail failing reason will be sent.
        open func retrieve(forKey key: String,
                               options: Option.OptionsInfo? = nil,
                               callbackQueue: CallbackQueue = .untouch,
                               completionHandler: ((Result<CachingSuccess, Error>) -> Void)?)
        {
            retrieve(
                forKey: key,
                options: Option.ParsedOptionsInfo(options),
                callbackQueue: callbackQueue,
                completionHandler: completionHandler)
        }
        
        func retrieveInMemoryCache(
            forKey key: String,
            options: Option.ParsedOptionsInfo) -> Item?
        {
            let computedKey = key.computedKey(with: options.processor.identifier)
            do {
                return try memoryStorage.value(forKey: computedKey)
            } catch {
                return nil
            }
        }
        
        /// Gets an item for a given key from the memory storage.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - options: The `FisherKitOptionsInfo` options setting used for retrieving the item.
        /// - Returns: The item stored in memory cache, if exists and valid. Otherwise, if the item does not exist or
        ///            has already expired, `nil` is returned.
        open func retrieveInMemoryCache(
            forKey key: String,
            options: Option.OptionsInfo? = nil) -> Item?
        {
            return retrieveInMemoryCache(forKey: key, options: Option.ParsedOptionsInfo(options))
        }
        
        func retrieveInDiskCache(
            forKey key: String,
            options: Option.ParsedOptionsInfo,
            callbackQueue: CallbackQueue = .untouch,
            completionHandler: @escaping (Result<Item?, Error>) -> Void)
        {
            let computedKey = key.computedKey(with: options.processor.identifier)
            let loadingQueue: CallbackQueue = options.loadDiskFileSynchronously ? .untouch : .dispatch(ioQueue)
            loadingQueue.execute {
                do {
                    var item: Item? = nil
                    if let data = try self.diskStorage.value(forKey: computedKey) {
                        
                        item = options.cacheSerializer.item(with: data, options: options)
                    }
                    callbackQueue.execute { completionHandler(.success(item)) }
                } catch {
                    if let error = error as? Error {
                        callbackQueue.execute { completionHandler(.failure(error)) }
                    } else {
                        assertionFailure("The internal thrown error should be a `FisherKitError`.")
                    }
                }
            }
        }
        
        /// Gets an item for a given key from the disk storage.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - options: The `FisherKitOptionsInfo` options setting used for retrieving the item.
        ///   - callbackQueue: The callback queue on which `completionHandler` is invoked. Default is `.untouch`.
        ///   - completionHandler: A closure which is invoked when the operation finishes.
        open func retrieveInDiskCache(
            forKey key: String,
            options: Option.OptionsInfo? = nil,
            callbackQueue: CallbackQueue = .untouch,
            completionHandler: @escaping (Result<Item?, Error>) -> Void)
        {
            retrieveInDiskCache(
                forKey: key,
                options: Option.ParsedOptionsInfo(options),
                callbackQueue: callbackQueue,
                completionHandler: completionHandler)
        }
        
        // MARK: Cleaning
        /// Clears the memory storage of this cache.
        @objc public func clearMemoryCache() {
            try? memoryStorage.removeAll()
        }
        
        /// Clears the disk storage of this cache. This is an async operation.
        ///
        /// - Parameter handler: A closure which is invoked when the cache clearing operation finishes.
        ///                      This `handler` will be called from the main queue.
        open func clearDiskCache(completion handler: (()->())? = nil) {
            ioQueue.async {
                do {
                    try self.diskStorage.removeAll()
                } catch _ { }
                if let handler = handler {
                    DispatchQueue.main.async { handler() }
                }
            }
        }
        
        /// Clears the expired items from disk storage. This is an async operation.
        open func cleanExpiredMemoryCache() {
            memoryStorage.removeExpired()
        }
        
        /// Clears the expired items from disk storage. This is an async operation.
        @objc func cleanExpiredDiskCache() {
            cleanExpiredDiskCache(completion: nil)
        }
        
        /// Clears the expired items from disk storage. This is an async operation.
        ///
        /// - Parameter handler: A closure which is invoked when the cache clearing operation finishes.
        ///                      This `handler` will be called from the main queue.
        open func cleanExpiredDiskCache(completion handler: (() -> Void)? = nil) {
            ioQueue.async {
                do {
                    var removed: [URL] = []
                    let removedExpired = try self.diskStorage.removeExpiredValues()
                    removed.append(contentsOf: removedExpired)
                    
                    let removedSizeExceeded = try self.diskStorage.removeSizeExceededValues()
                    removed.append(contentsOf: removedSizeExceeded)
                    
                    if !removed.isEmpty {
                        DispatchQueue.main.async {
                            let cleanedHashes = removed.map { $0.lastPathComponent }
                            NotificationCenter.default.post(
                                name: .FisherKitDidCleanDiskCache,
                                object: self,
                                userInfo: [FisherKitDiskCacheCleanedHashKey: cleanedHashes])
                        }
                    }
                    
                    if let handler = handler {
                        DispatchQueue.main.async { handler() }
                    }
                } catch {}
            }
        }
        
        #if !os(macOS) && !os(watchOS)
        /// Clears the expired items from disk storage when app is in background. This is an async operation.
        /// In most cases, you should not call this method explicitly.
        /// It will be called automatically when `UIApplicationDidEnterBackgroundNotification` received.
        @objc public func backgroundCleanExpiredDiskCache() {
            // if 'sharedApplication()' is unavailable, then return
            guard let sharedApplication = FisherKitWrapper<UIApplication>.shared else { return }
            
            func endBackgroundTask(_ task: inout UIBackgroundTaskIdentifier) {
                sharedApplication.endBackgroundTask(task)
                #if swift(>=4.2)
                task = UIBackgroundTaskIdentifier.invalid
                #else
                task = UIBackgroundTaskInvalid
                #endif
            }
            
            var backgroundTask: UIBackgroundTaskIdentifier!
            backgroundTask = sharedApplication.beginBackgroundTask {
                endBackgroundTask(&backgroundTask!)
            }
            
            cleanExpiredDiskCache {
                endBackgroundTask(&backgroundTask!)
            }
        }
        #endif
        
        // MARK: Item Cache State
        
        /// Returns the cache type for a given `key` and `identifier` combination.
        /// This method is used for checking whether an item is cached in current cache.
        /// It also provides information on which kind of cache can it be found in the return value.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - identifier: ProcessorType identifier which used for this item. Default is the `identifier` of
        ///                 `DefaultProcessor.default`.
        /// - Returns: A `CacheType` instance which indicates the cache status.
        ///            `.none` means the item is not in cache or it is already expired.
        open func cachedType(
            forKey key: String,
            processorIdentifier identifier: String = Processor.default.identifier) -> CacheType
        {
            let computedKey = key.computedKey(with: identifier)
            if memoryStorage.isCached(forKey: computedKey) { return .memory }
            if diskStorage.isCached(forKey: computedKey) { return .disk }
            return .none
        }
        
        /// Returns whether the file exists in cache for a given `key` and `identifier` combination.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - identifier: ProcessorType identifier which used for this item. Default is the `identifier` of
        ///                 `DefaultProcessor.default`.
        /// - Returns: A `Bool` which indicates whether a cache could match the given `key` and `identifier` combination.
        ///
        /// - Note:
        /// The return value does not contain information about from which kind of storage the cache matches.
        /// To get the information about cache type according `CacheType`,
        /// use `itemCachedType(forKey:processorIdentifier:)` instead.
        public func isCached(
            forKey key: String,
            processorIdentifier identifier: String = Processor.default.identifier) -> Bool
        {
            return cachedType(forKey: key, processorIdentifier: identifier).cached
        }
        
        /// Gets the hash used as cache file name for the key.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - identifier: ProcessorType identifier which used for this item. Default is the `identifier` of
        ///                 `DefaultProcessor.default`.
        /// - Returns: The hash which is used as the cache file name.
        ///
        /// - Note:
        /// By default, for a given combination of `key` and `identifier`, `Cache<Item>` will use the value
        /// returned by this method as the cache file name. You can use this value to check and match cache file
        /// if you need.
        open func hash(
            forKey key: String,
            processorIdentifier identifier: String = Processor.default.identifier) -> String
        {
            let computedKey = key.computedKey(with: identifier)
            return diskStorage.cacheFileName(forKey: computedKey)
        }
        
        /// Calculates the size taken by the disk storage.
        /// It is the total file size of all cached files in the `diskStorage` on disk in bytes.
        ///
        /// - Parameter handler: Called with the size calculating finishes. This closure is invoked from the main queue.
        open func calculateDiskStorageSize(completion handler: @escaping ((Result<UInt, Error>) -> Void)) {
            ioQueue.async {
                do {
                    let size = try self.diskStorage.totalSize()
                    DispatchQueue.main.async { handler(.success(size)) }
                } catch {
                    if let error = error as? Error {
                        DispatchQueue.main.async { handler(.failure(error)) }
                    } else {
                        assertionFailure("The internal thrown error should be a `FisherKitError`.")
                    }
                    
                }
            }
        }
        
        /// Gets the cache path for the key.
        /// It is useful for projects with web view or anyone that needs access to the local file path.
        ///
        /// i.e. Replacing the `<img src='path_for_key'>` tag in your HTML.
        ///
        /// - Parameters:
        ///   - key: The key used for caching the item.
        ///   - identifier: ProcessorType identifier which used for this item. Default is the `identifier` of
        ///                 `DefaultProcessor.default`.
        /// - Returns: The disk path of cached item under the given `key` and `identifier`.
        ///
        /// - Note:
        /// This method does not guarantee there is an item already cached in the returned path. It just gives your
        /// the path that the item should be, if it exists in disk storage.
        ///
        /// You could use `isCached(forKey:)` method to check whether the item is cached under that key in disk.
        open func cachePath(
            forKey key: String,
            processorIdentifier identifier: String = Processor.default.identifier) -> String
        {
            let computedKey = key.computedKey(with: identifier)
            return diskStorage.cacheFileURL(forKey: computedKey).path
        }
    }
}
