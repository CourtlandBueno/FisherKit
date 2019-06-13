//
//  DownloaderDelegate.swift
//  FisherKit
//
//  Created by Wei Wang on 2018/10/11.
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

/// Protocol of `Downloader`. This protocol provides a set of methods which are related to item downloader
/// working stages and rules.
public protocol DownloaderDelegate: AnyObject, ItemBound {
    
    typealias Downloader = FisherKitManager<Item>.Downloader
    /// Called when the `Downloader` object will start downloading an item from a specified URL.
    ///
    /// - Parameters:
    ///   - downloader: The `Downloader` object which is used for the downloading operation.
    ///   - url: URL of the starting request.
    ///   - request: The request object for the download process.
    ///
    func downloader(_ downloader: Downloader, willDownloadItemForURL url: URL, with request: URLRequest?)

    /// Called when the `Downloader` completes a downloading request with success or failure.
    ///
    /// - Parameters:
    ///   - downloader: The `Downloader` object which is used for the downloading operation.
    ///   - url: URL of the original request URL.
    ///   - response: The response object of the downloading process.
    ///   - error: The error in case of failure.
    ///
    func downloader(
        _ downloader: Downloader,
        didFinishDownloadingItemForURL url: URL,
        with response: URLResponse?,
        error: Swift.Error?)

    /// Called when the `Downloader` object successfully downloaded item data from specified URL. This is
    
    
    /// your last chance to verify or modify the downloaded data before FisherKit tries to perform addition
    /// processing on the item data.
    ///
    /// - Parameters:
    ///   - downloader: The `Downloader` object which is used for the downloading operation.
    ///   - data: The original downloaded data.
    ///   - url: The URL of the original request URL.
    /// - Returns: The data from which FisherKit should use to create an item. You need to provide valid data
    ///            which content is one of the supported item file format. FisherKit will perform process on this
    ///            data and try to convert it to an item object.
    /// - Note:
    ///   This can be used to pre-process raw item data before creation of `Item` instance (i.e.
    ///   decrypting or verification). If `nil` returned, the processing is interrupted and a `FisherKitError` with
    ///   `ResponseErrorReason.dataModifyingFailed` will be raised. You could use this fact to stop the item
    ///   processing flow if you find the data is corrupted or malformed.
    func downloader(_ downloader: Downloader, didDownload data: Data, for url: URL) -> Data?

    /// Called when the `Downloader` object successfully downloads and processes an item from specified URL.
    ///
    /// - Parameters:
    ///   - downloader: The `Downloader` object which is used for the downloading operation.
    ///   - item: The downloaded and processed item.
    ///   - url: URL of the original request URL.
    ///   - response: The original response object of the downloading process.
    ///
    func downloader(
        _ downloader: Downloader,
        didDownload item: Item,
        for url: URL,
        with response: URLResponse?)

    /// Checks if a received HTTP status code is valid or not.
    /// By default, a status code in range 200..<400 is considered as valid.
    /// If an invalid code is received, the downloader will raise an `FisherKitError` with
    /// `ResponseErrorReason.invalidHTTPStatusCode` as its reason.
    ///
    /// - Parameters:
    ///   - code: The received HTTP status code.
    ///   - downloader: The `Downloader` object asks for validate status code.
    /// - Returns: Returns a value to indicate whether this HTTP status code is valid or not.
    /// - Note: If the default 200 to 400 valid code does not suit your need,
    ///         you can implement this method to change that behavior.
    func isValidStatusCode(_ code: Int, for downloader: Downloader) -> Bool
}

// Default implementation for `DownloaderDelegate`.
extension DownloaderDelegate {
    public func downloader(
        _ downloader: Downloader,
        willDownloadItemForURL url: URL,
        with request: URLRequest?) {}

    public func downloader(
        _ downloader: Downloader,
        didFinishDownloadingItemForURL url: URL,
        with response: URLResponse?,
        error: Swift.Error?) {}

    public func downloader(
        _ downloader: Downloader,
        didDownload item: Item,
        for url: URL,
        with response: URLResponse?) {}

    public func isValidStatusCode(_ code: Int, for downloader: Downloader) -> Bool {
        return (200..<400).contains(code)
    }
    public func downloader(_ downloader: Downloader, didDownload data: Data, for url: URL) -> Data? {
        return data
    }
}
