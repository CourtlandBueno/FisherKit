//
//  Image.swift
//  FisherKit
//
//  Created by Courtland Bueno on 3/8/19.
//
#if !os(Linux)

#if os(macOS)
import AppKit
public typealias Image = NSImage
private var imagesKey: Void?
private var durationKey: Void?
#else
public typealias Image = UIImage
import UIKit
import MobileCoreServices
private var imageSourceKey: Void?
#endif
import CoreGraphics
import ImageIO

extension Image: FisherKitItemType {
    public static var itemTypeDescription: String { return "Image" }
}
extension Image: FisherKitCompatible {
    
}


extension FisherKitWrapper where Base == Image {
    
    public var decoded: Base {
        return decoded(scale: scale)
    }
    /// Returns decoded image of the `base` image at a given scale. It will draw the image in a plain context and
    /// return the data from it. This could improve the drawing performance when an image is just created from
    /// data but not yet displayed for the first time.
    ///
    /// - Parameter scale: The given scale of target image should be.
    /// - Returns: The decoded image ready to be displayed.
    ///
    /// - Note: This method only works for CG-based image. The current image scale is kept.
    ///         For any non-CG-based image or animated image, `base` itself is returned.
    public func decoded(scale: CGFloat) -> Image {
        // Prevent animated image (GIF) losing it's images
        #if os(iOS)
        if imageSource != nil { return base }
        #else
        if images != nil { return base }
        #endif
        
        guard let imageRef = cgImage else {
            assertionFailure("[Kingfisher] Decoding only works for CG-based image.")
            return base
        }
        
        let size = CGSize(width: CGFloat(imageRef.width) / scale, height: CGFloat(imageRef.height) / scale)
        return draw(to: size, inverting: true, scale: scale) { context in
            context.draw(imageRef, in: CGRect(origin: .zero, size: size))
        }
    }
}
private var animatedImageDataKey: Void?

extension Image: CacheCostCalculable {
    public var cacheCost: Int {
        return fk.cost
    }
}

// MARK: - Image Properties
extension FisherKitWrapper where Base: Image {
    private(set) var animatedImageData: Data? {
        get { return getAssociatedObject(base, &animatedImageDataKey) }
        set { setRetainedAssociatedObject(base, &animatedImageDataKey, newValue) }
    }
    
    #if os(macOS)
    var cgImage: CGImage? {
        return base.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    var scale: CGFloat {
        return 1.0
    }
    
    private(set) var images: [Image]? {
        get { return getAssociatedObject(base, &imagesKey) }
        set { setRetainedAssociatedObject(base, &imagesKey, newValue) }
    }
    
    private(set) var duration: TimeInterval {
        get { return getAssociatedObject(base, &durationKey) ?? 0.0 }
        set { setRetainedAssociatedObject(base, &durationKey, newValue) }
    }
    
    var size: CGSize {
        return base.representations.reduce(.zero) { size, rep in
            let width = max(size.width, CGFloat(rep.pixelsWide))
            let height = max(size.height, CGFloat(rep.pixelsHigh))
            return CGSize(width: width, height: height)
        }
    }
    #else
    var cgImage: CGImage? { return base.cgImage }
    var scale: CGFloat { return base.scale }
    var images: [Image]? { return base.images }
    var duration: TimeInterval { return base.duration }
    var size: CGSize { return base.size }
    
    private(set) var imageSource: CGImageSource? {
        get { return getAssociatedObject(base, &imageSourceKey) }
        set { setRetainedAssociatedObject(base, &imageSourceKey, newValue) }
    }
    #endif
    
    // Bitmap memory cost with bytes.
    var cost: Int {
        let pixel = Int(size.width * size.height * scale * scale)
        guard let cgImage = cgImage else {
            return pixel * 4
        }
        return pixel * cgImage.bitsPerPixel / 8
    }
}

// MARK: - Image Conversion
extension FisherKitWrapper where Base: Image {
    #if os(macOS)
    static func image(cgImage: CGImage, scale: CGFloat, refImage: Image?) -> Image {
        return Image(cgImage: cgImage, size: .zero)
    }
    
    /// Normalize the image. This getter does nothing on macOS but return the image itself.
    public var normalized: Image { return base }
    
    #else
    /// Creating an image from a give `CGImage` at scale and orientation for refImage. The method signature is for
    /// compatibility of macOS version.
    static func image(cgImage: CGImage, scale: CGFloat, refImage: Image?) -> Image {
        return Image(cgImage: cgImage, scale: scale, orientation: refImage?.imageOrientation ?? .up)
    }
    
    /// Returns normalized image for current `base` image.
    /// This method will try to redraw an image with orientation and scale considered.
    public var normalized: Image {
        // prevent animated image (GIF) lose it's images
        guard images == nil else { return base }
        // No need to do anything if already up
        guard base.imageOrientation != .up else { return base }
        
        return draw(to: size) { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    #endif
}

// MARK: - Image Representation
extension FisherKitWrapper where Base: Image {
    /// Returns PNG representation of `base` image.
    ///
    /// - Returns: PNG data of image.
    public func pngRepresentation() -> Data? {
        #if os(macOS)
        guard let cgImage = cgImage else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
        #else
        #if swift(>=4.2)
        return base.pngData()
        #else
        return UIImagePNGRepresentation(base)
        #endif
        #endif
    }
    
    /// Returns JPEG representation of `base` image.
    ///
    /// - Parameter compressionQuality: The compression quality when converting image to JPEG data.
    /// - Returns: JPEG data of image.
    public func jpegRepresentation(compressionQuality: CGFloat) -> Data? {
        #if os(macOS)
        guard let cgImage = cgImage else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using:.jpeg, properties: [.compressionFactor: compressionQuality])
        #else
        #if swift(>=4.2)
        return base.jpegData(compressionQuality: compressionQuality)
        #else
        return UIImageJPEGRepresentation(base, compressionQuality)
        #endif
        #endif
    }
    
    /// Returns GIF representation of `base` image.
    ///
    /// - Returns: Original GIF data of image.
    public func gifRepresentation() -> Data? {
        return animatedImageData
    }
}

// MARK: - Creating Images
extension FisherKitWrapper where Base: Image {
    
    /// Creates an animated image from a given data and options. Currently only GIF data is supported.
    ///
    /// - Parameters:
    ///   - data: The animated image data.
    ///   - options: Options to use when creating the animated image.
    /// - Returns: An `Image` object represents the animated image. It is in form of an array of image frames with a
    ///            certain duration. `nil` if anything wrong when creating animated image.
    public static func animatedImage(data: Data, options: ImageCreatingOptions) -> Image? {
        let info: [String: Any] = [
            kCGImageSourceShouldCache as String: true,
            kCGImageSourceTypeIdentifierHint as String: kUTTypeGIF
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, info as CFDictionary) else {
            return nil
        }
        
        #if os(macOS)
        guard let animatedImage = GIFAnimatedImage(from: imageSource, for: info, options: options) else {
            return nil
        }
        var image: Image?
        if options.onlyFirstFrame {
            image = animatedImage.images.first
        } else {
            image = Image(data: data)
            var fk = image?.fk
            fk?.images = animatedImage.images
            fk?.duration = animatedImage.duration
        }
        image?.fk.animatedImageData = data
        return image
        #else
        
        var image: Image?
        if options.preloadAll || options.onlyFirstFrame {
            // Use `images` image if you want to preload all animated data
            guard let animatedImage = GIFAnimatedImage(from: imageSource, for: info, options: options) else {
                return nil
            }
            if options.onlyFirstFrame {
                image = animatedImage.images.first
            } else {
                let duration = options.duration <= 0.0 ? animatedImage.duration : options.duration
                image = .animatedImage(with: animatedImage.images, duration: duration)
            }
            image?.fk.animatedImageData = data
        } else {
            image = Image(data: data, scale: options.scale)
            var fk = image?.fk
            fk?.imageSource = imageSource
            fk?.animatedImageData = data
        }
        
        return image
        #endif
    }
    
    /// Creates an image from a given data and options. `.JPEG`, `.PNG` or `.GIF` is supported. For other
    /// image format, image initializer from system will be used. If no image object could be created from
    /// the given `data`, `nil` will be returned.
    ///
    /// - Parameters:
    ///   - data: The image data representation.
    ///   - options: Options to use when creating the image.
    /// - Returns: An `Image` object represents the image if created. If the `data` is invalid or not supported, `nil`
    ///            will be returned.
    public static func image(data: Data, options: ImageCreatingOptions) -> Image? {
        var image: Image?
        switch data.fk.imageFormat {
        case .JPEG:
            image = Image(data: data, scale: options.scale)
        case .PNG:
            image = Image(data: data, scale: options.scale)
        case .GIF:
            image = FisherKitWrapper.animatedImage(data: data, options: options)
        case .unknown:
            image = Image(data: data, scale: options.scale)
        }
        return image
    }
    
    /// Creates a downsampled image from given data to a certain size and scale.
    ///
    /// - Parameters:
    ///   - data: The image data contains a JPEG or PNG image.
    ///   - pointSize: The target size in point to which the image should be downsampled.
    ///   - scale: The scale of result image.
    /// - Returns: A downsampled `Image` object following the input conditions.
    ///
    /// - Note:
    /// Different from image `resize` methods, downsampling will not render the original
    /// input image in pixel format. It does downsampling from the image data, so it is much
    /// more memory efficient and friendly. Choose to use downsampling as possible as you can.
    ///
    /// The input size should be smaller than the size of input image. If it is larger than the
    /// original image size, the result image will be the same size of input without downsampling.
    public static func downsampledImage(data: Data, to pointSize: CGSize, scale: CGFloat) -> Image? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        return FisherKitWrapper.image(cgImage: downsampledImage, scale: scale, refImage: nil)
    }
}


extension FisherKitManager where Item == Image {
    public convenience init() {
        self.init(downloader: .default, cache: .default)
        
        self.defaultOptions += [
            .processor(FisherKitManager.defaultProcessor),
            .cacheSerializer(FisherKitManager.defaultSerializer)
        ]
    }
}

#endif
