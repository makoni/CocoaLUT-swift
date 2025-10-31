import CoreGraphics
import Foundation
import ImageIO
import simd
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum LUTFormatterUnwrappedTextureError: Error, Equatable, LocalizedError {
    case unsupportedBitDepth
    case invalidDimensions
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .unsupportedBitDepth:
            return "Only 8-bit or 16-bit unwrapped texture images are supported."
        case .invalidDimensions:
            return "The image dimensions do not match the unwrapped texture layout."
        case .unsupportedImage:
            return "The image could not be decoded as an unwrapped texture LUT."
        }
    }
}

enum LUTFormatterUnwrappedTexture {
    static let formatterIdentifier = "unwrappedCube"

    struct Options {
        fileprivate var base: ImageBasedFormatterOptions

        init(bitDepth: Int = 8) {
            guard let options = ImageBasedFormatterOptions(variant: .tiff, bitDepth: bitDepth) else {
                preconditionFailure("Unsupported bit depth \(bitDepth) for TIFF metadata")
            }
            self.base = options
        }

        fileprivate init(base: ImageBasedFormatterOptions) {
            self.base = base
        }

        var bitDepth: Int { base.bitDepth }

        func metadata(lutSize: Int? = nil) -> ImageBasedFormatterMetadata {
            ImageBasedFormatterMetadata(options: base, lutSize: lutSize)
        }

        static func from(passthrough options: [String: Any]) -> Options? {
            guard let metadata = ImageBasedFormatterMetadata.fromPassthrough(options,
                                                                             formatterID: formatterIdentifier) else {
                return nil
            }
            return Options(base: metadata.options)
        }
    }

    static func image(from lut: LUT3D, options: Options = Options()) throws -> CGImage {
        let bitDepth = options.bitDepth
        guard bitDepth == 8 || bitDepth == 16 else {
            throw LUTFormatterUnwrappedTextureError.unsupportedBitDepth
        }

        let size = lut.size
        let width = size * size
        let height = size
        do {
            return try ImageBasedLUTUtilities.makeRGBImage(width: width,
                                                           height: height,
                                                           bitDepth: bitDepth) { write in
                writePixels(lut: lut, size: size, width: width) { index, color in
                    write(index, color)
                }
            }
        } catch let error as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(error)
        }
    }

    static func pngData(from lut: LUT3D, options: Options = Options()) throws -> Data {
        let image = try image(from: lut, options: options)
        do {
            return try ImageBasedLUTUtilities.pngData(from: image)
        } catch let error as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(error)
        }
    }

    #if canImport(AppKit)
    @MainActor
    static func nsImage(from lut: LUT3D, options: Options = Options()) throws -> NSImage {
        let cgImage = try image(from: lut, options: options)
        return ImageBasedFormatterPlatformBridge.nsImage(from: cgImage)
    }

    @MainActor
    static func read(nsImage: NSImage) throws -> LUT3D {
        guard let cgImage = ImageBasedFormatterPlatformBridge.cgImage(from: nsImage) else {
            throw LUTFormatterUnwrappedTextureError.unsupportedImage
        }
        return try read(image: cgImage)
    }
    #endif

    #if canImport(UIKit)
    static func uiImage(from lut: LUT3D, options: Options = Options()) throws -> UIImage {
        let cgImage = try image(from: lut, options: options)
        return ImageBasedFormatterPlatformBridge.uiImage(from: cgImage)
    }

    static func read(uiImage: UIImage) throws -> LUT3D {
        guard let cgImage = ImageBasedFormatterPlatformBridge.cgImage(from: uiImage) else {
            throw LUTFormatterUnwrappedTextureError.unsupportedImage
        }
        return try read(image: cgImage)
    }
    #endif

    static func read(image: CGImage) throws -> LUT3D {
        let width = image.width
        let height = image.height
        guard height > 0, width == height * height else {
            throw LUTFormatterUnwrappedTextureError.invalidDimensions
        }

        let size = height
        let expectedEntries = width * height
        let bitDepth = ImageBasedLUTUtilities.bitDepth(of: image)
        guard bitDepth == 8 || bitDepth == 16 else { throw LUTFormatterUnwrappedTextureError.unsupportedBitDepth }

        let pixelData: [SIMD3<Double>]
        do {
            pixelData = try ImageBasedLUTUtilities.normalizedPixelData(from: image)
        } catch let error as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(error)
        }
        guard pixelData.count == expectedEntries else {
            throw LUTFormatterUnwrappedTextureError.unsupportedImage
        }

        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for (index, color) in pixelData.enumerated() {
            let x = index % width
            let y = index / width
            let r = x % size
            let b = x / size
            let g = y
            let lutColor = LUTColor.color(red: color.x, green: color.y, blue: color.z)
            lut.setColor(lutColor, r: r, g: g, b: b)
        }

        lut.passthroughFileOptions = passthroughOptions(lutSize: size, bitDepth: bitDepth)
        return lut
    }

    static func read(data: Data) throws -> LUT3D {
        do {
            let image = try ImageBasedLUTUtilities.image(from: data)
            return try read(image: image)
        } catch let error as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(error)
        }
    }

    private static func passthroughOptions(lutSize: Int, bitDepth: Int) -> [String: Any] {
        guard let dictionary = ImageBasedFormatterMetadata.passthroughDictionary(formatterID: formatterIdentifier,
                                                                                variant: .tiff,
                                                                                bitDepth: bitDepth,
                                                                                lutSize: lutSize) else {
            preconditionFailure("Unsupported bit depth \(bitDepth) for TIFF metadata")
        }
        return dictionary
    }

    private static func writePixels(lut: LUT3D,
                                    size: Int,
                                    width: Int,
                                    handler: (_ index: Int, _ color: LUTColor) -> Void) {
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let x = b * size + r
                    let y = g
                    let index = y * width + x
                    let color = lut.colorAt(r: r, g: g, b: b)
                    handler(index, color)
                }
            }
        }
    }

    private static func mapUtilitiesError(_ error: ImageBasedLUTUtilitiesError) -> LUTFormatterUnwrappedTextureError {
        switch error {
        case .unsupportedBitDepth:
            return .unsupportedBitDepth
        case .unsupportedImage:
            return .unsupportedImage
        }
    }
}
