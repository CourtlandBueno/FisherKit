//
//  Indicator.swift
//  FisherKit
//
//  Created by João D. Moreira on 30/08/16.
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
#if !os(Linux)
#if canImport(AppKit)
import AppKit
public typealias IndicatorView = NSView
#else
import UIKit
public typealias IndicatorView = UIView
#endif

/// Represents the activity indicator type which should be added to
/// an item view when an item is being downloaded.
///
/// - none: No indicator.
/// - activity: Uses the system activity indicator.
/// - item: Uses an item as indicator. GIF is supported.
/// - custom: Uses a custom indicator. The type of associated value should conform to the `Indicator` protocol.
public enum IndicatorType {
    /// No indicator.
    case none
    /// Uses the system activity indicator.
    case activity
    /// Uses an item as indicator. GIF is supported.
    case item(itemData: Data)
    /// Uses a custom indicator. The type of associated value should conform to the `Indicator` protocol.
    case custom(indicator: Indicator)
}

/// An indicator type which can be used to show the download task is in progress.
public protocol Indicator {
    
    /// Called when the indicator should start animating.
    func startAnimatingView()
    
    /// Called when the indicator should stop animating.
    func stopAnimatingView()

    /// Center offset of the indicator. FisherKit will use this value to determine the position of
    /// indicator in the super view.
    var centerOffset: CGPoint { get }
    
    /// The indicator view which would be added to the super view.
    var view: IndicatorView { get }
}

extension Indicator {
    
    /// Default implementation of `centerOffset` of `Indicator`. The default value is `.zero`, means that there is
    /// no offset for the indicator view.
    public var centerOffset: CGPoint { return .zero }
}

// Displays a NSProgressIndicator / UIActivityIndicatorView
final class ActivityIndicator: Indicator {

    #if os(macOS)
    private let activityIndicatorView: NSProgressIndicator
    #else
    private let activityIndicatorView: UIActivityIndicatorView
    #endif
    private var animatingCount = 0

    var view: IndicatorView {
        return activityIndicatorView
    }

    func startAnimatingView() {
        if animatingCount == 0 {
            #if os(macOS)
            activityIndicatorView.startAnimation(nil)
            #else
            activityIndicatorView.startAnimating()
            #endif
            activityIndicatorView.isHidden = false
        }
        animatingCount += 1
    }

    func stopAnimatingView() {
        animatingCount = max(animatingCount - 1, 0)
        if animatingCount == 0 {
            #if os(macOS)
                activityIndicatorView.stopAnimation(nil)
            #else
                activityIndicatorView.stopAnimating()
            #endif
            activityIndicatorView.isHidden = true
        }
    }

    init() {
        #if os(macOS)
            activityIndicatorView = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
            activityIndicatorView.controlSize = .small
            activityIndicatorView.style = .spinning
        #else
            #if os(tvOS)
                let indicatorStyle = UIActivityIndicatorView.Style.white
            #else
                let indicatorStyle = UIActivityIndicatorView.Style.gray
            #endif
            #if swift(>=4.2)
            activityIndicatorView = UIActivityIndicatorView(style: indicatorStyle)
            #else
            activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: indicatorStyle)
            #endif
        #endif
    }
}
#endif
