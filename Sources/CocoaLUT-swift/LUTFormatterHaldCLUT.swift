import CoreGraphics
import Foundation
import ImageIO
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
        do {
            return try ImageBasedLUTUtilities.makeRGBImage(width: width,
                                                           height: height,
                                                           bitDepth: bitDepth) { write in
                writePixels(lut: lut, width: width, height: height, size: size) { index, color in
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

    static func read(image: CGImage) throws -> LUT3D {
        guard image.width == image.height else { throw LUTHaldCLUTFormatterError.mismatchedImageDimensions }

        let width = image.width
        let order = Int(pow(Double(width), 1.0 / 3.0).rounded())
        guard order > 0, order * order * order == width else { throw LUTHaldCLUTFormatterError.mismatchedImageDimensions }

        let size = order * order
        let expectedEntries = size * size * size
        guard width * width == expectedEntries else { throw LUTHaldCLUTFormatterError.mismatchedImageDimensions }

        let bitDepth = ImageBasedLUTUtilities.bitDepth(of: image)
        guard bitDepth == 8 || bitDepth == 16 else { throw LUTHaldCLUTFormatterError.unsupportedBitDepth }

        let pixelData: [SIMD3<Double>]
        do {
            pixelData = try ImageBasedLUTUtilities.normalizedPixelData(from: image)
        } catch let error as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(error)
        }
        guard pixelData.count == expectedEntries else { throw LUTHaldCLUTFormatterError.unsupportedImage }

        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for (index, color) in pixelData.enumerated() {
            let redIndex = index % size
            let greenIndex = (index / size) % size
            let blueIndex = index / (size * size)
            let lutColor = LUTColor.color(red: color.x, green: color.y, blue: color.z)
            lut.setColor(lutColor, r: redIndex, g: greenIndex, b: blueIndex)
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

    private static func mapUtilitiesError(_ error: ImageBasedLUTUtilitiesError) -> LUTHaldCLUTFormatterError {
        switch error {
        case .unsupportedBitDepth:
            return .unsupportedBitDepth
        case .unsupportedImage:
            return .unsupportedImage
        }
    }
}
