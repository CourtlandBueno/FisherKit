//
//  NSButton+Kingfisher.swift
//  Kingfisher
//
//  Created by Jie Zhang on 14/04/2016.
//
//  Copyright (c) 2019 Wei Wang <onevcat@gmail.com>
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
#if canImport(AppKit)
import AppKit

extension FisherKitWrapper where Base: NSButton {

    // MARK: Setting Image

    /// Sets an image to the button with a source.
    ///
    /// - Parameters:
    ///   - source: The `Source` object contains information about how to get the image.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `FisherKitManager<Image>.Option.OptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested source.
    /// Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setImage(
        through manager: FisherKitManager<Image>,
        with source: Source?,
        placeholder: Image? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) -> FisherKitManager<Image>.DownloadTask?
    {
        var mutatingSelf = self
        guard let source = source else {
            base.image = placeholder
            mutatingSelf.taskIdentifier = nil
            completionHandler?(.failure(FisherKitManager<Image>.Error.itemSettingError(reason: .emptySource)))
            return nil
        }

        let options = FisherKitManager<Image>.Option.ParsedOptionsInfo(manager.defaultOptions + (options ?? .empty))
        if !options.keepCurrentItemWhileLoading {
            base.image = placeholder
        }

        let issuedIdentifier = Source.Identifier.next()
        mutatingSelf.taskIdentifier = issuedIdentifier

        let task = manager.retrieve(
            with: source,
            options: options,
            progressBlock: { receivedSize, totalSize in
                guard issuedIdentifier == self.taskIdentifier else { return }
                progressBlock?(receivedSize, totalSize)
            },
            completionHandler: { result in
                DispatchQueue.main.safeAsync {
                    guard issuedIdentifier == self.taskIdentifier else {
                        let reason: FisherKitManager<Image>.Error.ItemSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: value, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = FisherKitManager<Image>.Error.itemSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }

                    mutatingSelf.imageTask = nil

                    switch result {
                    case .success(let value):
                        self.base.image = value.item
                        completionHandler?(result)
                    case .failure:
                        if let image = options.onFailureItem {
                            self.base.image = image
                        }
                        completionHandler?(result)
                    }
                }
            }
        )

        mutatingSelf.imageTask = task
        return task
    }

    /// Sets an image to the button with a requested resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object contains information about the resource.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `FisherKitManager<Image>.Option.OptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested resource, from either cache
    /// or network. Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setImage(
        through manager: FisherKitManager<Image>,
        with resource: Resource?,
        placeholder: Image? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) ->FisherKitManager<Image>.DownloadTask?
    {
        return setImage(
            through: manager,
            with: resource.map { .network($0) },
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    // MARK: Cancelling Downloading Task

    /// Cancels the image download task of the button if it is running.
    /// Nothing will happen if the downloading has already finished.
    public func cancelImageDownloadTask() {
        imageTask?.cancel()
    }

    // MARK: Setting Alternate Image

    @discardableResult
    public func setAlternateImage(
        through manager: FisherKitManager<Image>,
        with source: Source?,
        placeholder: Image? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) ->FisherKitManager<Image>.DownloadTask?
    {
        var mutatingSelf = self
        guard let source = source else {
            base.alternateImage = placeholder
            mutatingSelf.alternateTaskIdentifier = nil
            completionHandler?(.failure(FisherKitManager<Image>.Error.itemSettingError(reason: .emptySource)))
            return nil
        }
        let options = FisherKitManager<Image>.Option.ParsedOptionsInfo(manager.defaultOptions + (options ?? .empty))
        
        if !options.keepCurrentItemWhileLoading {
            base.alternateImage = placeholder
        }

        let issuedIdentifier = Source.Identifier.next()
        mutatingSelf.alternateTaskIdentifier = issuedIdentifier
        let task = manager.retrieve(
            with: source,
            options: options,
            progressBlock: { receivedSize, totalSize in
                guard issuedIdentifier == self.alternateTaskIdentifier else { return }
                progressBlock?(receivedSize, totalSize)
            },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.alternateTaskIdentifier else {
                        let reason: FisherKitManager<Image>.Error.ItemSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: value, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = FisherKitManager<Image>.Error.itemSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }

                    mutatingSelf.alternateImageTask = nil

                    switch result {
                    case .success(let value):
                        self.base.alternateImage = value.item
                        completionHandler?(result)
                    case .failure:
                        if let image = options.onFailureItem {
                            self.base.alternateImage = image
                        }
                        completionHandler?(result)
                    }
                }
            }
        )

        mutatingSelf.alternateImageTask = task
        return task
    }

    /// Sets an alternate image to the button with a requested resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object contains information about the resource.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `FisherKitManager<Image>.Option.OptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested resource, from either cache
    /// or network. Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setAlternateImage(
        through manager: FisherKitManager<Image>,
        with resource: Resource?,
        placeholder: Image? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) ->FisherKitManager<Image>.DownloadTask?
    {
        return setAlternateImage(
            through: manager,
            with: resource.map { .network($0) },
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    // MARK: Cancelling Alternate Image Downloading Task

    /// Cancels the alternate image download task of the button if it is running.
    /// Nothing will happen if the downloading has already finished.
    public func cancelAlternateImageDownloadTask() {
        alternateImageTask?.cancel()
    }
}


// MARK: - Associated Object
private var taskIdentifierKey: Void?
private var imageTaskKey: Void?

private var alternateTaskIdentifierKey: Void?
private var alternateImageTaskKey: Void?

extension FisherKitWrapper where Base: NSButton {

    // MARK: Properties
    
    public private(set) var taskIdentifier: Source.Identifier.Value? {
        get {
            let box: Box<Source.Identifier.Value>? = getAssociatedObject(base, &taskIdentifierKey)
            return box?.value
        }
        set {
            let box = newValue.map { Box($0) }
            setRetainedAssociatedObject(base, &taskIdentifierKey, box)
        }
    }
    
    private var imageTask: FisherKitManager<Image>.DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue)}
    }

    public private(set) var alternateTaskIdentifier: Source.Identifier.Value? {
        get {
            let box: Box<Source.Identifier.Value>? = getAssociatedObject(base, &alternateTaskIdentifierKey)
            return box?.value
        }
        set {
            let box = newValue.map { Box($0) }
            setRetainedAssociatedObject(base, &alternateTaskIdentifierKey, box)
        }
    }

    private var alternateImageTask: FisherKitManager<Image>.DownloadTask? {
        get { return getAssociatedObject(base, &alternateImageTaskKey) }
        set { setRetainedAssociatedObject(base, &alternateImageTaskKey, newValue)}
    }
}
#endif
