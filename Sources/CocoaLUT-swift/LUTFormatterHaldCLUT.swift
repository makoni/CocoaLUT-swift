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

enum LUTHaldCLUTFormatterError: Error, Equatable, LocalizedError {
    case unsupportedBitDepth
    case invalidLUTSize
    case mismatchedImageDimensions
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .unsupportedBitDepth:
            return "Only 8-bit or 16-bit Hald CLUT images are supported."
        case .invalidLUTSize:
            return "The LUT size for a Hald CLUT must be a perfect square."
        case .mismatchedImageDimensions:
            return "Hald CLUT images must be square with cubic dimensions."
        case .unsupportedImage:
            return "The image could not be decoded as a Hald CLUT."
        }
    }
}

enum LUTFormatterHaldCLUT {
    static let formatterIdentifier = "haldCLUT"

    struct Options {
        var bitDepth: Int

        init(bitDepth: Int = 8) {
            self.bitDepth = bitDepth
        }
    }

    static func image(from lut: LUT3D, options: Options = Options()) throws -> CGImage {
        let bitDepth = options.bitDepth
        guard bitDepth == 8 || bitDepth == 16 else { throw LUTHaldCLUTFormatterError.unsupportedBitDepth }

        let size = lut.size
        let order = Int(Double(size).squareRoot().rounded())
        guard order * order == size else { throw LUTHaldCLUTFormatterError.invalidLUTSize }

        let width = order * size
        let height = width
        let bytesPerComponent = bitDepth / 8
        let bytesPerPixel = 3 * bytesPerComponent
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = bytesPerRow * height

        var storage = Data(count: bufferSize)
        storage.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            if bitDepth == 8 {
                let pointer = baseAddress.bindMemory(to: UInt8.self, capacity: bufferSize)
                writePixels(lut: lut, width: width, height: height, size: size) { index, color in
                    let base = index * 3
                    pointer[base + 0] = UInt8(clamping: Int((color.red * 255.0).rounded()))
                    pointer[base + 1] = UInt8(clamping: Int((color.green * 255.0).rounded()))
                    pointer[base + 2] = UInt8(clamping: Int((color.blue * 255.0).rounded()))
                }
            } else {
                let pointer = baseAddress.bindMemory(to: UInt16.self, capacity: bufferSize / 2)
                writePixels(lut: lut, width: width, height: height, size: size) { index, color in
                    let base = index * 3
                    let maxValue = 65535.0
                    pointer[base + 0] = UInt16(clamping: Int((color.red * maxValue).rounded())).littleEndian
                    pointer[base + 1] = UInt16(clamping: Int((color.green * maxValue).rounded())).littleEndian
                    pointer[base + 2] = UInt16(clamping: Int((color.blue * maxValue).rounded())).littleEndian
                }
            }
        }

        guard let provider = CGDataProvider(data: storage as CFData) else {
            throw LUTHaldCLUTFormatterError.unsupportedImage
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
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
            throw LUTHaldCLUTFormatterError.unsupportedImage
        }

        return image
    }

    static func pngData(from lut: LUT3D, options: Options = Options()) throws -> Data {
        let image = try image(from: lut, options: options)
        let data = NSMutableData()
        let type: CFString
        #if canImport(UniformTypeIdentifiers)
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            type = UTType.png.identifier as CFString
        } else {
            type = kUTTypePNG
        }
        #else
        type = kUTTypePNG
        #endif
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else {
            throw LUTHaldCLUTFormatterError.unsupportedImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw LUTHaldCLUTFormatterError.unsupportedImage
        }
        return data as Data
    }

    static func read(image: CGImage) throws -> LUT3D {
        guard image.width == image.height else { throw LUTHaldCLUTFormatterError.mismatchedImageDimensions }

        let width = image.width
        let order = Int(pow(Double(width), 1.0 / 3.0).rounded())
        guard order > 0, order * order * order == width else { throw LUTHaldCLUTFormatterError.mismatchedImageDimensions }

        let size = order * order
        let expectedEntries = size * size * size
        guard width * width == expectedEntries else { throw LUTHaldCLUTFormatterError.mismatchedImageDimensions }

        let pixelData = try normalizedPixelData(from: image)
        guard pixelData.count == expectedEntries else { throw LUTHaldCLUTFormatterError.unsupportedImage }

        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for (index, color) in pixelData.enumerated() {
            let redIndex = index % size
            let greenIndex = (index / size) % size
            let blueIndex = index / (size * size)
            let lutColor = LUTColor.color(red: color.x, green: color.y, blue: color.z)
            lut.setColor(lutColor, r: redIndex, g: greenIndex, b: blueIndex)
        }

        lut.passthroughFileOptions = passthroughOptions(lutSize: size, bitDepth: 8)
        return lut
    }

    static func read(data: Data) throws -> LUT3D {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LUTHaldCLUTFormatterError.unsupportedImage
        }
        return try read(image: image)
    }

    private static func passthroughOptions(lutSize: Int, bitDepth: Int) -> [String: Any] {
        [formatterIdentifier: ["lutSize": lutSize, "bitDepth": bitDepth]]
    }

    private static func writePixels(lut: LUT3D,
                                    width: Int,
                                    height: Int,
                                    size: Int,
                                    handler: (_ index: Int, _ color: LUTColor) -> Void) {
        for y in 0..<height {
            for x in 0..<width {
                let cubeIndex = y * width + x
                let redIndex = cubeIndex % size
                let greenIndex = (cubeIndex / size) % size
                let blueIndex = cubeIndex / (size * size)
                let color = lut.colorAt(r: redIndex, g: greenIndex, b: blueIndex)
                handler(cubeIndex, color)
            }
        }
    }

    private static func normalizedPixelData(from image: CGImage) throws -> [SIMD3<Double>] {
        let width = image.width
        let height = image.height
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
            throw LUTHaldCLUTFormatterError.unsupportedImage
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        guard let dataPointer = context.data else { throw LUTHaldCLUTFormatterError.unsupportedImage }

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
}
