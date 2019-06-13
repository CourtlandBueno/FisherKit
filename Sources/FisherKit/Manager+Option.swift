//
//  Manager+Option.swift
//  FisherKit-MacOS
//
//  Created by Courtland Bueno on 3/6/19.
//

import Foundation

extension Array {
    static var empty: Array {
        return Array()
    }
}

public protocol InfoItemType: ItemBound {
    
}

public protocol ParsedOptionsInfoType: ItemBound {
    associatedtype InfoItem: InfoItemType where InfoItem.Item == Self.Item
    typealias OptionsInfo = [InfoItem]
    init(_ info: OptionsInfo?)
}

public protocol ManagedOptions: ItemBound {
    associatedtype InfoItem: InfoItemType where InfoItem.Item == Item
    associatedtype ParsedOptionsInfo: ParsedOptionsInfoType where ParsedOptionsInfo.Item == Item
    typealias OptionsInfo = ParsedOptionsInfo.OptionsInfo
    
    static func parse(_ options: OptionsInfo) -> ParsedOptionsInfo
}

public protocol OptionBound: ItemBound {
    associatedtype Option: ManagedOptions
}

extension FisherKitManager {
    
    public enum Option: ManagedOptions {
        
        public static func parse(_ options: OptionsInfo) -> ParsedOptionsInfo {
            return .init(options)
        }
        
        public typealias OptionsInfo = [InfoItem]
        
        public enum InfoItem: InfoItemType {
            
            /// FisherKit will use the associated `Cache<Item>` object when handling related operations,
            /// including trying to retrieve the cached items and store the downloaded item to it.
            case targetCache(Cache)
            
            /// The `Cache<Item>` for storing and retrieving original items. If `originalCache` is
            /// contained in the options, it will be preferred for storing and retrieving original items.
            /// If there is no `.originalCache` in the options, `.targetCache` will be used to store original items.
            ///
            /// When using FisherKitManager to download and store an item, if `cacheOriginalItem` is
            /// applied in the option, the original item will be stored to this `originalCache`. At the
            /// same time, if a requested final item (with processor applied) cannot be found in `targetCache`,
            /// FisherKit will try to search the original item to check whether it is already there. If found,
            /// it will be used and applied with the given processor. It is an optimization for not downloading
            /// the same item for multiple times.
            case originalCache(Cache)
            
            /// FisherKit will use the associated `Downloader` object to download the requested items.
            case downloader(Downloader)
            
            
            /// Associated `Float` value will be set as the priority of item download task. The value for it should be
            /// between 0.0~1.0. If this option not set, the default value (`URLSessionTask.defaultPriority`) will be used.
            case downloadPriority(Float)
            
            /// If set, FisherKit will ignore the cache and try to fire a download task for the resource.
            case forceRefresh
            
            /// If set, FisherKit will try to retrieve the item from memory cache first. If the item is not in memory
            /// cache, then it will ignore the disk cache but download the item again from network. This is useful when
            /// you want to display a changeable item behind the same url at the same app session, while avoiding download
            /// it for multiple times.
            case fromMemoryCacheOrRefresh
            
            ///  If set, FisherKit will only cache the value in memory but not in disk.
            case cacheMemoryOnly
            
            ///  If set, FisherKit will wait for caching operation to be completed before calling the completion block.
            case waitForCache
            
            /// If set, FisherKit will only try to retrieve the item from cache, but not from network. If the item is
            /// not in cache, the item retrieving will fail with an error.
            case onlyFromCache
            
            /// Decode the item in background thread before using. It will decode the downloaded item data and do a off-screen
            /// rendering to extract pixel information in background. This can speed up display, but will cost more time to
            /// prepare the item for using.
            case backgroundDecode
            
            /// The associated value will be used as the target queue of dispatch callbacks when retrieving items from
            /// cache. If not set, FisherKit will use `.mainCurrentOrAsync` for callbacks.
            ///
            /// - Note:
            /// This option does not affect the callbacks for UI related extension methods. You will always get the
            /// callbacks called from main queue.
            case callbackQueue(CallbackQueue)
            
            
            /// The `ItemDownloadRequestModifier` contained will be used to change the request before it being sent.
            /// This is the last chance you can modify the item download request. You can modify the request for some
            /// customizing purpose, such as adding auth token to the header, do basic HTTP auth or something like url mapping.
            /// The original request will be sent without any modification by default.
            case requestModifier(DownloadRequestModifier)
            
            /// The `ItemDownloadRedirectHandler` contained will be used to change the request before redirection.
            /// This is the posibility you can modify the item download request during redirect. You can modify the request for
            /// some customizing purpose, such as adding auth token to the header, do basic HTTP auth or something like url
            /// mapping.
            /// The original redirection request will be sent without any modification by default.
            case redirectHandler(RedirectHandler)
            
            /// Processor for processing when the downloading finishes, a processor will convert the downloaded data to an item
            /// and/or apply some filter on it. If a cache is connected to the downloader (it happens when you are using
            /// FisherKitManager or any of the view extension methods), the converted item will also be sent to cache as well.
            /// If not set, the `DefaultItemProcessor.default` will be used.
            case processor(Processor)
            
            /// Supplies a `CacheSerializer` to convert some data to an item object for
            /// retrieving from disk cache or vice versa for storing to disk cache.
            /// If not set, the `DefaultCacheSerializer.default` will be used.
            case cacheSerializer(Cache.Serializer)
            
            /// An `Modifier` is for modifying an image as needed right before it is used. If the image was fetched
            /// directly from the downloader, the modifier will run directly after the `Processor`. If the image is being
            /// fetched from a cache, the modifier will run after the `Cache.Serializer`.
            case modifier(Modifier)
            
            /// Keep the existing item of item view while setting another item to it.
            /// By setting this option, the placeholder item parameter of item view extension method
            /// will be ignored and the current item will be kept while loading or downloading the new item.
            case keepCurrentItemWhileLoading
            
            /// If set and a `Processor` is used, FisherKit will try to cache both the final result and original
            /// item. FisherKit will have a chance to use the original item when another processor is applied to the same
            /// resource, instead of downloading it again. You can use `.originalCache` to specify a cache or the original
            /// items if necessary.
            ///
            /// The original item will be only cached to disk storage.
            case cacheOriginalItem
            
            /// If set and a downloading error occurred FisherKit will set provided item (or empty)
            /// in place of requested one. It's useful when you don't want to show placeholder
            /// during loading time but wants to use some default item when requests will be failed.
            case onFailureItem(Item?)
            
            /// If set and used in `ItemPrefetcher`, the prefetching operation will load the items into memory storage
            /// aggressively. By default this is not contained in the options, that means if the requested item is already
            /// in disk cache, FisherKit will not try to load it to memory.
            case alsoPrefetchToMemory
            
            /// If set, the disk storage loading will happen in the same calling queue. By default, disk storage file loading
            /// happens in its own queue with an asynchronous dispatch behavior. Although it provides better non-blocking disk
            /// loading performance, it also causes a flickering when you reload an item from disk, if the item view already
            /// has an item set.
            ///
            /// Set this options will stop that flickering by keeping all loading in the same queue (typically the UI queue
            /// if you are using FisherKit's extension methods to set an item), with a tradeoff of loading performance.
            case loadDiskFileSynchronously
            
            /// The expiration setting for memory cache. By default, the underlying `MemoryStorage.Backend` uses the
            /// expiration in its config for all items. If set, the `MemoryStorage.Backend` will use this associated
            /// value to overwrite the config setting for this caching item.
            case memoryCacheExpiration(StorageExpiration)
            
            /// The expiration setting for memory cache. By default, the underlying `DiskStorage.Backend` uses the
            /// expiration in its config for all items. If set, the `DiskStorage.Backend` will use this associated
            /// value to overwrite the config setting for this caching item.
            case diskCacheExpiration(StorageExpiration)
            
            /// Decides on which queue the item processing should happen. By default, FisherKit uses a pre-defined serial
            /// queue to process items. Use this option to change this behavior. For example, specify a `.mainCurrentOrAsync`
            /// to let the item be processed in main queue to prevent a possible flickering (but with a possibility of
            /// blocking the UI, especially if the processor needs a lot of time to run).
            case processingQueue(CallbackQueue)
            
            case dataProcessingInfo([String : String])
        }

        // Improve performance by parsing the input `FisherKitOptionsInfo` (self) first.
        // So we can prevent the iterating over the options array again and again.
        /// The parsed options info used across FisherKit methods. Each property in this type corresponds a case member
        /// in `FisherKitOptionsInfoItem`. When a `FisherKitOptionsInfo` sent to FisherKit related methods, it will be
        /// parsed and converted to a `FisherKitParsedOptionsInfo` first, and pass through the internal methods.
        @dynamicMemberLookup
        public struct ParsedOptionsInfo: ParsedOptionsInfoType {
            
            public subscript(dynamicMember member: String) -> String {
                get {
                    return dataProcessingInfo[member] ?? ""
                }
                set {
                    dataProcessingInfo[member] = newValue
                }
            }
            
            public var targetCache: Cache? = nil
            public var originalCache: Cache? = nil
            public var downloader: Downloader? = nil
            public var downloadPriority: Float = URLSessionTask.defaultPriority
            public var forceRefresh = false
            public var fromMemoryCacheOrRefresh = false
            public var cacheMemoryOnly = false
            public var waitForCache = false
            public var onlyFromCache = false
            public var backgroundDecode = false
            public var preloadAllAnimationData = false
            public var callbackQueue: CallbackQueue = .mainCurrentOrAsync
            public var requestModifier: DownloadRequestModifier? = nil
            public var redirectHandler: RedirectHandler? = nil
            public var processor: Processor = .default
            public var cacheSerializer: Cache.Serializer = .default
            public var modifier: Modifier? = nil
            public var keepCurrentItemWhileLoading = false
            public var cacheOriginalItem = false
            public var onFailureItem: Optional<Item?> = .none
            public var alsoPrefetchToMemory = false
            public var loadDiskFileSynchronously = false
            public var memoryCacheExpiration: StorageExpiration? = nil
            public var diskCacheExpiration: StorageExpiration? = nil
            public var processingQueue: CallbackQueue? = nil
            public var dataProcessingInfo: [String:String] = [:]
            
            
            public init(_ info: OptionsInfo?) {
                guard let info = info else { return }
                for option in info {
                    switch option {
                    case .targetCache(let value): targetCache = value
                    case .originalCache(let value): originalCache = value
                    case .downloader(let value): downloader = value
                    case .downloadPriority(let value): downloadPriority = value
                    case .forceRefresh: forceRefresh = true
                    case .fromMemoryCacheOrRefresh: fromMemoryCacheOrRefresh = true
                    case .cacheMemoryOnly: cacheMemoryOnly = true
                    case .waitForCache: waitForCache = true
                    case .onlyFromCache: onlyFromCache = true
                    case .backgroundDecode: backgroundDecode = true
                    case .callbackQueue(let value): callbackQueue = value
                    case .requestModifier(let value): requestModifier = value
                    case .redirectHandler(let value): redirectHandler = value
                    case .processor(let value): processor = value
                    case .cacheSerializer(let value): cacheSerializer = value
                    case .modifier(let value): modifier = value
                    case .keepCurrentItemWhileLoading: keepCurrentItemWhileLoading = true
                    case .cacheOriginalItem: cacheOriginalItem = true
                    case .onFailureItem(let value): onFailureItem = .some(value)
                    case .alsoPrefetchToMemory: alsoPrefetchToMemory = true
                    case .loadDiskFileSynchronously: loadDiskFileSynchronously = true
                    case .memoryCacheExpiration(let expiration): memoryCacheExpiration = expiration
                    case .diskCacheExpiration(let expiration): diskCacheExpiration = expiration
                    case .processingQueue(let queue): processingQueue = queue
                    case .dataProcessingInfo(let value): dataProcessingInfo = value
                    }
                }
                
                if originalCache == nil {
                    originalCache = targetCache
                }
            }
            
            
            public init<S: Sequence>(_ info: S?) where InfoItem == S.Element  {
                guard let info = info else { return }
                for option in info {
                    switch option {
                    case .targetCache(let value): targetCache = value
                    case .originalCache(let value): originalCache = value
                    case .downloader(let value): downloader = value
                    case .downloadPriority(let value): downloadPriority = value
                    case .forceRefresh: forceRefresh = true
                    case .fromMemoryCacheOrRefresh: fromMemoryCacheOrRefresh = true
                    case .cacheMemoryOnly: cacheMemoryOnly = true
                    case .waitForCache: waitForCache = true
                    case .onlyFromCache: onlyFromCache = true
                    case .backgroundDecode: backgroundDecode = true
                    case .callbackQueue(let value): callbackQueue = value
                    case .requestModifier(let value): requestModifier = value
                    case .redirectHandler(let value): redirectHandler = value
                    case .processor(let value): processor = value
                    case .cacheSerializer(let value): cacheSerializer = value
                    case .modifier(let value): modifier = value
                    case .keepCurrentItemWhileLoading: keepCurrentItemWhileLoading = true
                    case .cacheOriginalItem: cacheOriginalItem = true
                    case .onFailureItem(let value): onFailureItem = .some(value)
                    case .alsoPrefetchToMemory: alsoPrefetchToMemory = true
                    case .loadDiskFileSynchronously: loadDiskFileSynchronously = true
                    case .memoryCacheExpiration(let expiration): memoryCacheExpiration = expiration
                    case .diskCacheExpiration(let expiration): diskCacheExpiration = expiration
                    case .processingQueue(let queue): processingQueue = queue
                    case .dataProcessingInfo(let value): dataProcessingInfo = value
                    }
                }
                
                if originalCache == nil {
                    originalCache = targetCache
                }
            }
        }
        
    }
    
}
