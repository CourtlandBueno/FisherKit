//
//  ImageModifier.swift
//  FisherKi
//
//  Created by Ethan Gill on 2017/11/28.
//
//  Copyright (c) 2019 Ethan Gill <ethan.gill@me.com>
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
#if canImport(UIKit)
import Foundation
import UIKit

extension FisherKitManager where Item == Image {
    
    public func renderingModeImageModifier(renderingMode: UIImage.RenderingMode) -> Modifier {
        return Modifier(RenderingModeImageModifier(renderingMode: renderingMode))
    }
    
    /// Modifier for setting the rendering mode of images.
    public struct RenderingModeImageModifier: ModifierType {
        
        /// The rendering mode to apply to the image.
        public let renderingMode: UIImage.RenderingMode
        
        /// Creates a `RenderingModeImageModifier`.
        ///
        /// - Parameter renderingMode: The rendering mode to apply to the image. Default is `.automatic`.
        public init(renderingMode: UIImage.RenderingMode = .automatic) {
            self.renderingMode = renderingMode
        }
        
        /// Modify an input `Image`. See `ImageModifier` protocol for more.
        public func modify(_ item: Item) -> Item {
            return item.withRenderingMode(renderingMode)
        }
    }
    
    static var flipsForRightToLeftLayoutDirectionImageModifier: Modifier {
        return Modifier.init { image in
            return image.imageFlippedForRightToLeftLayoutDirection()
        }
    }
    
    static func alignmentRectInsetsImageModifier(alignmentInsets: UIEdgeInsets) -> Modifier {
        return Modifier(AlignmentRectInsetsImageModifier(alignmentInsets: alignmentInsets))
    }
    /// Modifier for setting the `alignmentRectInsets` property of images.
    public struct AlignmentRectInsetsImageModifier: ModifierType {
        
        /// The alignment insets to apply to the image
        public let alignmentInsets: UIEdgeInsets
        
        /// Creates an `AlignmentRectInsetsImageModifier`.
        public init(alignmentInsets: UIEdgeInsets) {
            self.alignmentInsets = alignmentInsets
        }
        
        /// Modify an input `Image`. See `ImageModifier` protocol for more.
        public func modify(_ item: Item) -> Item {
            return item.withAlignmentRectInsets(alignmentInsets)
        }
    }
}

#endif
#endif
