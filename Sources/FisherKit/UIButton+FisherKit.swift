//
//  UIButton+Kingfisher.swift
//  Kingfisher
//
//  Created by Wei Wang on 15/4/13.
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
#if canImport(UIKit)
import UIKit

extension FisherKitWrapper where Base: UIButton {

    // MARK: Setting Image
    /// Sets an image to the button for a specified state with a source.
    ///
    /// - Parameters:
    ///   - source: The `Source` object contains information about the image.
    ///   - state: The button state to which the image should be set.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `FisherKitManager<Image>.Option.OptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested source, from either cache
    /// or network. Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setImage(
        through manager: FisherKitManager<Image>,
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) -> FisherKitManager<Image>.DownloadTask?
    {
        guard let source = source else {
            base.setImage(placeholder, for: state)
            setTaskIdentifier(nil, for: state)
            completionHandler?(.failure(FisherKitManager<Image>.Error.itemSettingError(reason: .emptySource)))
            return nil
        }
        
        let options = FisherKitManager<Image>.Option.ParsedOptionsInfo(manager.defaultOptions + (options ?? .empty))
        if !options.keepCurrentItemWhileLoading {
            base.setImage(placeholder, for: state)
        }
        
        var mutatingSelf = self
        let issuedTaskIdentifier = Source.Identifier.next()
        setTaskIdentifier(issuedTaskIdentifier, for: state)
        let task = manager.retrieve(
            with: source,
            options: options,
            progressBlock: { receivedSize, totalSize in
                guard issuedTaskIdentifier == self.taskIdentifier(for: state) else { return }
                progressBlock?(receivedSize, totalSize)
            },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedTaskIdentifier == self.taskIdentifier(for: state) else {
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
                        self.base.setImage(value.item, for: state)
                        completionHandler?(result)
                    case .failure:
                        if let image = options.onFailureItem {
                            self.base.setImage(image, for: state)
                        }
                        completionHandler?(result)
                    }
                }
        })
        
        mutatingSelf.imageTask = task
        return task
    }
    
    /// Sets an image to the button for a specified state with a requested resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object contains information about the resource.
    ///   - state: The button state to which the image should be set.
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
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) ->FisherKitManager<Image>.DownloadTask?
    {
        return setImage(
            through: manager,
            with: resource.map { Source.network($0) },
            for: state,
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

    // MARK: Setting Background Image

    /// Sets a background image to the button for a specified state with a source.
    ///
    /// - Parameters:
    ///   - source: The `Source` object contains information about the image.
    ///   - state: The button state to which the image should be set.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `FisherKitManager<Image>.Option.OptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested source
    /// Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setBackgroundImage(
        through manager: FisherKitManager<Image>,
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) ->FisherKitManager<Image>.DownloadTask?
    {
        guard let source = source else {
            base.setBackgroundImage(placeholder, for: state)
            setBackgroundTaskIdentifier(nil, for: state)
            completionHandler?(.failure(FisherKitManager<Image>.Error.itemSettingError(reason: .emptySource)))
            return nil
        }
    let options = FisherKitManager<Image>.Option.ParsedOptionsInfo(manager.defaultOptions + (options ?? .empty))
        
        if !options.keepCurrentItemWhileLoading {
            base.setBackgroundImage(placeholder, for: state)
        }
        
        var mutatingSelf = self
        let issuedTaskIdentifier = Source.Identifier.next()
        setBackgroundTaskIdentifier(issuedTaskIdentifier, for: state)
        let task = manager.retrieve(
            with: source,
            options: options,
            progressBlock: { receivedSize, totalSize in
                guard issuedTaskIdentifier == self.backgroundTaskIdentifier(for: state) else {
                    return
                }
                if let progressBlock = progressBlock {
                    progressBlock(receivedSize, totalSize)
                }
            },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedTaskIdentifier == self.backgroundTaskIdentifier(for: state) else {
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
                    mutatingSelf.backgroundImageTask = nil

                    switch result {
                    case .success(let value):
                        self.base.setBackgroundImage(value.item, for: state)
                        completionHandler?(result)
                    case .failure:
                        if let image = options.onFailureItem {
                            self.base.setBackgroundImage(image, for: state)
                        }
                        completionHandler?(result)
                    }
                }
        })

        mutatingSelf.backgroundImageTask = task
        return task
    }

    /// Sets a background image to the button for a specified state with a requested resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object contains information about the resource.
    ///   - state: The button state to which the image should be set.
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
    public func setBackgroundImage(
        through manager: FisherKitManager<Image>,
        with resource: Resource?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: FisherKitManager<Image>.Option.OptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<FisherKitManager<Image>.RetrievalSuccess, FisherKitManager<Image>.Error>) -> Void)? = nil) ->FisherKitManager<Image>.DownloadTask?
    {
        return setBackgroundImage(
            through: manager,
            with: resource.map { .network($0) },
            for: state,
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    // MARK: Cancelling Background Downloading Task
    
    /// Cancels the background image download task of the button if it is running.
    /// Nothing will happen if the downloading has already finished.
    public func cancelBackgroundImageDownloadTask() {
        backgroundImageTask?.cancel()
    }
}

// MARK: - Associated Object
private var taskIdentifierKey: Void?
private var imageTaskKey: Void?

// MARK: Properties
extension FisherKitWrapper where Base: UIButton {

    public func taskIdentifier(for state: UIControl.State) -> Source.Identifier.Value? {
        return (taskIdentifierInfo[NSNumber(value:state.rawValue)] as? Box<Source.Identifier.Value>)?.value
    }

    private func setTaskIdentifier(_ identifier: Source.Identifier.Value?, for state: UIControl.State) {
        taskIdentifierInfo[NSNumber(value:state.rawValue)] = identifier.map { Box($0) }
    }
    
    private var taskIdentifierInfo: NSMutableDictionary {
        get {
            guard let dictionary: NSMutableDictionary = getAssociatedObject(base, &taskIdentifierKey) else {
                let dic = NSMutableDictionary()
                var mutatingSelf = self
                mutatingSelf.taskIdentifierInfo = dic
                return dic
            }
            return dictionary
        }
        set {
            setRetainedAssociatedObject(base, &taskIdentifierKey, newValue)
        }
    }
    
    private var imageTask:FisherKitManager<Image>.DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue)}
    }
}


private var backgroundTaskIdentifierKey: Void?
private var backgroundImageTaskKey: Void?

// MARK: Background Properties
extension FisherKitWrapper where Base: UIButton {

    public func backgroundTaskIdentifier(for state: UIControl.State) -> Source.Identifier.Value? {
        return (backgroundTaskIdentifierInfo[NSNumber(value:state.rawValue)] as? Box<Source.Identifier.Value>)?.value
    }
    
    private func setBackgroundTaskIdentifier(_ identifier: Source.Identifier.Value?, for state: UIControl.State) {
        backgroundTaskIdentifierInfo[NSNumber(value:state.rawValue)] = identifier.map { Box($0) }
    }
    
    private var backgroundTaskIdentifierInfo: NSMutableDictionary {
        get {
            guard let dictionary: NSMutableDictionary = getAssociatedObject(base, &backgroundTaskIdentifierKey) else {
                let dic = NSMutableDictionary()
                var mutatingSelf = self
                mutatingSelf.backgroundTaskIdentifierInfo = dic
                return dic
            }
            return dictionary
        }
        set {
            setRetainedAssociatedObject(base, &backgroundTaskIdentifierKey, newValue)
        }
    }
    
    private var backgroundImageTask:FisherKitManager<Image>.DownloadTask? {
        get { return getAssociatedObject(base, &backgroundImageTaskKey) }
        mutating set { setRetainedAssociatedObject(base, &backgroundImageTaskKey, newValue) }
    }
}
#endif
