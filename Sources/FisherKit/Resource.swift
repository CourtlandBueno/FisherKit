//
//  Resource.swift
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

/// Represents an item resource at a certain url and a given cache key.
/// FisherKit will use a `Resource` to download a resource from network and cache it with the cache key when
/// using `Source.network` as its item setting source.
public protocol ResourceType {
    
    /// The key used in cache.
    var cacheKey: String { get }
    
    /// The target item URL.
    var downloadURL: URL { get }
}

/// Resource is a simple combination of `downloadURL` and `cacheKey`.
/// When passed to item view set methods, FisherKit will try to download the target
/// item from the `downloadURL`, and then store it with the `cacheKey` as the key in cache.
public struct Resource: ResourceType {

    // MARK: - Initializers

    /// Creates an item resource.
    ///
    /// - Parameters:
    ///   - downloadURL: The target item URL from where the item can be downloaded.
    ///   - cacheKey: The cache key. If `nil`, FisherKit will use the `absoluteString` of `downloadURL` as the key.
    ///               Default is `nil`.
    public init(downloadURL: URL, cacheKey: String? = nil) {
        self.downloadURL = downloadURL
        self.cacheKey = cacheKey ?? downloadURL.absoluteString
    }

    // MARK: Protocol Conforming
    
    /// The key used in cache.
    public let cacheKey: String

    /// The target item URL.
    public let downloadURL: URL
}

/// URL conforms to `Resource` in FisherKit.
/// The `absoluteString` of this URL is used as `cacheKey`. And the URL itself will be used as `downloadURL`.
/// If you need customize the url and/or cache key, use `Resource` instead.
extension URL: ResourceType {
    public var cacheKey: String { return absoluteString }
    public var downloadURL: URL { return self }
}
