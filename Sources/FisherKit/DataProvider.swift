//
//  DataProvider.swift
//  FisherKit
//
//  Created by courtland.bueno on 2018/11/13.
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

/// Represents a data provider to provide item data to FisherKit when setting with
/// `Source.provider` source. Compared to `Source.network` member, it gives a chance
/// to load some item data in your own way, as long as you can provide the data
/// representation for the item.
public protocol DataProvider {
    
    /// The key used in cache.
    var cacheKey: String { get }
    
    /// Provides the data which represents item. FisherKit uses the data you pass in the
    /// handler to process items and caches it for later use.
    ///
    /// - Parameter handler: The handler you should call when you prepared your data.
    ///                      If the data is loaded successfully, call the handler with
    ///                      a `.success` with the data associated. Otherwise, call it
    ///                      with a `.failure` and pass the error.
    ///
    /// - Note:
    /// If the `handler` is called with a `.failure` with error, a `dataProviderError` of
    /// `ItemSettingErrorReason` will be finally thrown out to you as the `FisherKitError`
    /// from the framework.
    func data(handler: @escaping (Result<Data, Error>) -> Void)
}

/// Represents an item data provider for loading from a local file URL on disk.
/// Uses this type for adding a disk item to FisherKit. Compared to loading it
/// directly, you can get benefit of using FisherKit's extension methods, as well
/// as applying `ProcessorType`s and storing the item to `Cache<Item>` of FisherKit.
public struct LocalFileDataProvider: DataProvider {

    // MARK: Public Properties

    /// The file URL from which the item be loaded.
    public let fileURL: URL

    // MARK: Initializers

    /// Creates an item data provider by supplying the target local file URL.
    ///
    /// - Parameters:
    ///   - fileURL: The file URL from which the item be loaded.
    ///   - cacheKey: The key is used for caching the item data. By default,
    ///               the `absoluteString` of `fileURL` is used.
    public init(fileURL: URL, cacheKey: String? = nil) {
        self.fileURL = fileURL
        self.cacheKey = cacheKey ?? fileURL.absoluteString
    }

    // MARK: Protocol Conforming

    /// The key used in cache.
    public var cacheKey: String

    public func data(handler: (Result<Data, Error>) -> Void) {
        handler(Result(catching: { try Data(contentsOf: fileURL) }))
    }
}

/// Represents an item data provider for loading item from a given Base64 encoded string.
public struct Base64DataProvider: DataProvider {

    // MARK: Public Properties
    /// The encoded Base64 string for the item.
    public let base64String: String

    // MARK: Initializers

    /// Creates an item data provider by supplying the Base64 encoded string.
    ///
    /// - Parameters:
    ///   - base64String: The Base64 encoded string for an item.
    ///   - cacheKey: The key is used for caching the item data. You need a different key for any different item.
    public init(base64String: String, cacheKey: String) {
        self.base64String = base64String
        self.cacheKey = cacheKey
    }

    // MARK: Protocol Conforming

    /// The key used in cache.
    public var cacheKey: String

    public func data(handler: (Result<Data, Error>) -> Void) {
        let data = Data(base64Encoded: base64String)!
        handler(.success(data))
    }
}

/// Represents an item data provider for a raw data object.
public struct RawDataProvider: DataProvider {

    // MARK: Public Properties

    /// The raw data object to provide to FisherKit item loader.
    public let data: Data

    // MARK: Initializers

    /// Creates an item data provider by the given raw `data` value and a `cacheKey` be used in FisherKit cache.
    ///
    /// - Parameters:
    ///   - data: The raw data reprensents an item.
    ///   - cacheKey: The key is used for caching the item data. You need a different key for any different item.
    public init(data: Data, cacheKey: String) {
        self.data = data
        self.cacheKey = cacheKey
    }

    // MARK: Protocol Conforming
    
    /// The key used in cache.
    public var cacheKey: String

    public func data(handler: @escaping (Result<Data, Error>) -> Void) {
        handler(.success(data))
    }
}
