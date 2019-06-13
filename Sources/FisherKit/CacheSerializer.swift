//
//  CacheSerializerType.swift
//  FisherKit
//
//  Created by Wei Wang on 2016/09/02.
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

/// An `CacheSerializerType` is used to convert some data to an item object after
/// retrieving it from disk storage, and vice versa, to convert an item to data object
/// for storing to the disk storage.
public protocol CacheSerializerType: OptionBound {
    
    var identifier: String { get }
    /// Gets the serialized data from a provided item
    /// and optional original data for caching to disk.
    ///
    /// - Parameters:
    ///   - item: The item needed to be serialized.
    ///   - original: The original data which is just downloaded.
    ///               If the item is retrieved from cache instead of
    ///               downloaded, it will be `nil`.
    /// - Returns: The data object for storing to disk, or `nil` when no valid
    ///            data could be serialized.
    func data(with item: Item, original: Data?, options: Option.ParsedOptionsInfo) -> Data?

    /// Gets an item from provided serialized data.
    ///
    /// - Parameters:
    ///   - data: The data from which an item should be deserialized.
    ///   - options: The parsed options for deserialization.
    /// - Returns: An item deserialized or `nil` when no valid item
    ///            could be deserialized.
    func item(with data: Data, options: Option.ParsedOptionsInfo) -> Item?
}
