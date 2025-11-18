import CoreGraphics
import Foundation
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(MobileCoreServices)
import MobileCoreServices
#elseif canImport(CoreServices)
import CoreServices
#endif
import simd

enum ImageBasedLUTUtilitiesError: Error, Equatable, LocalizedError {
    case unsupportedBitDepth
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .unsupportedBitDepth:
            return "Only 8-bit or 16-bit RGB images are supported for LUT conversion."
        case .unsupportedImage:
            return "The image could not be processed for LUT conversion."
        }
    }
}

enum ImageBasedLUTUtilities {
    static func makeRGBImage(width: Int,
                             height: Int,
                             bitDepth: Int,
                             populate: (_ write: (Int, LUTColor) -> Void) -> Void) throws -> CGImage {
        let data = try makeRGBData(width: width, height: height, bitDepth: bitDepth, populate: populate)
        guard let provider = CGDataProvider(data: data as CFData) else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerComponent = bitDepth / 8
        let bytesPerPixel = 3 * bytesPerComponent
        let bytesPerRow = width * bytesPerPixel

        let bitmapInfo: CGBitmapInfo
        if bitDepth == 8 {
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        } else {
            bitmapInfo = [CGBitmapInfo.byteOrder16Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)]
        }

        guard let image = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: bitDepth,
                                  bitsPerPixel: bitDepth * 3,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo,
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }

        return image
    }

    static func normalizedPixelData(from image: CGImage) throws -> [SIMD3<Double>] {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        guard let dataPointer = context.data else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }

        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        var pixels = [SIMD3<Double>](repeating: .zero, count: width * height)

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let columnOffset = x * bytesPerPixel
                let offset = rowOffset + columnOffset
                let red = Double(buffer[offset + 0]) / 255.0
                let green = Double(buffer[offset + 1]) / 255.0
                let blue = Double(buffer[offset + 2]) / 255.0
                pixels[y * width + x] = SIMD3(red, green, blue)
            }
        }

        return pixels
    }

    static func pngData(from image: CGImage) throws -> Data {
        try data(from: image, preferredType: .png)
    }

    static func tiffData(from image: CGImage) throws -> Data {
        try data(from: image, preferredType: .tiff)
    }

    static func image(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }
        return image
    }

    static func bitDepth(of image: CGImage) -> Int {
        image.bitsPerComponent
    }

    private static func makeRGBData(width: Int,
                                     height: Int,
                                     bitDepth: Int,
                                     populate: (_ write: (Int, LUTColor) -> Void) -> Void) throws -> Data {
        guard bitDepth == 8 || bitDepth == 16 else {
            throw ImageBasedLUTUtilitiesError.unsupportedBitDepth
        }

        let bytesPerComponent = bitDepth / 8
        let bytesPerPixel = 3 * bytesPerComponent
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = bytesPerRow * height

        var storage = Data(count: bufferSize)
        storage.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            if bitDepth == 8 {
                let pointer = baseAddress.bindMemory(to: UInt8.self, capacity: bufferSize)
                populate { index, color in
                    let base = index * 3
                    pointer[base + 0] = UInt8(clamping: Int((color.red * 255.0).rounded()))
                    pointer[base + 1] = UInt8(clamping: Int((color.green * 255.0).rounded()))
                    pointer[base + 2] = UInt8(clamping: Int((color.blue * 255.0).rounded()))
                }
            } else {
                let pointer = baseAddress.bindMemory(to: UInt16.self, capacity: bufferSize / 2)
                let maxValue = 65535.0
                populate { index, color in
                    let base = index * 3
                    pointer[base + 0] = UInt16(clamping: Int((color.red * maxValue).rounded())).littleEndian
                    pointer[base + 1] = UInt16(clamping: Int((color.green * maxValue).rounded())).littleEndian
                    pointer[base + 2] = UInt16(clamping: Int((color.blue * maxValue).rounded())).littleEndian
                }
            }
        }

        return storage
    }

    private enum ExportType {
        case png
        case tiff

        var uti: CFString {
            #if canImport(UniformTypeIdentifiers)
            if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
                switch self {
                case .png:
                    return UTType.png.identifier as CFString
                case .tiff:
                    return UTType.tiff.identifier as CFString
                }
            }
            #endif
            switch self {
            case .png:
                return kUTTypePNG
            case .tiff:
                return kUTTypeTIFF
            }
        }
    }

    private static func data(from image: CGImage, preferredType: ExportType) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, preferredType.uti, 1, nil) else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageBasedLUTUtilitiesError.unsupportedImage
        }
        return data as Data
    }
}
