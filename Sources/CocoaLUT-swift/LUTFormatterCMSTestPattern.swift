import CoreGraphics
import Foundation
import ImageIO
import simd

enum LUTFormatterCMSTestPatternError: Error, Equatable, LocalizedError {
    case unsupportedBitDepth
    case invalidDimensions
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .unsupportedBitDepth:
            return "Only 8-bit or 16-bit CMS test pattern images are supported."
        case .invalidDimensions:
            return "Image dimensions do not match the CMS test pattern specification."
        case .unsupportedImage:
            return "The image could not be decoded as a CMS test pattern LUT."
        }
    }
}

enum LUTFormatterCMSTestPattern {
    static let formatterIdentifier = "cms"
    private static let blockSize = 7

    struct Options {
        var bitDepth: Int

        init(bitDepth: Int = 8) {
            self.bitDepth = bitDepth
        }
    }

    static func image(from lut: LUT3D, options: Options = Options()) throws -> CGImage {
        let bitDepth = options.bitDepth
        guard bitDepth == 8 || bitDepth == 16 else { throw LUTFormatterCMSTestPatternError.unsupportedBitDepth }

        let layout = layoutForCubeSize(lut.size)
        do {
            return try ImageBasedLUTUtilities.makeRGBImage(width: layout.pixelWidth,
                                                           height: layout.pixelHeight,
                                                           bitDepth: bitDepth) { write in
                writePixels(from: lut,
                            layout: layout) { pixelIndex, color in
                    write(pixelIndex, color)
                }
            }
        } catch let utilitiesError as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(utilitiesError)
        }
    }

    static func pngData(from lut: LUT3D, options: Options = Options()) throws -> Data {
        let image = try image(from: lut, options: options)
        do {
            return try ImageBasedLUTUtilities.pngData(from: image)
        } catch let utilitiesError as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(utilitiesError)
        }
    }

    static func read(image: CGImage) throws -> LUT3D {
        guard image.width % blockSize == 0, image.height % blockSize == 0 else {
            throw LUTFormatterCMSTestPatternError.invalidDimensions
        }

        let bitDepth = ImageBasedLUTUtilities.bitDepth(of: image)
        guard bitDepth == 8 || bitDepth == 16 else { throw LUTFormatterCMSTestPatternError.unsupportedBitDepth }

        let layout = try layoutFromImage(width: image.width, height: image.height)

        let pixels: [SIMD3<Double>]
        do {
            pixels = try ImageBasedLUTUtilities.normalizedPixelData(from: image)
        } catch let utilitiesError as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(utilitiesError)
        }
        guard pixels.count == layout.pixelWidth * layout.pixelHeight else {
            throw LUTFormatterCMSTestPatternError.unsupportedImage
        }

        var lut = LUT3D(size: layout.cubeSize, inputLowerBound: 0, inputUpperBound: 1)
        let totalEntries = layout.cubeSize * layout.cubeSize * layout.cubeSize
        for yBlock in 0..<layout.heightBlocks {
            for xBlock in 0..<layout.widthBlocks {
                let cubeIndex = yBlock * layout.widthBlocks + xBlock
                guard cubeIndex < totalEntries else { continue }

                let redIndex = cubeIndex % layout.cubeSize
                let greenIndex = (cubeIndex / layout.cubeSize) % layout.cubeSize
                let blueIndex = cubeIndex / (layout.cubeSize * layout.cubeSize)

                let sampleX = xBlock * blockSize
                let sampleY = (layout.heightBlocks - (yBlock + 1)) * blockSize
                let pixelIndex = sampleY * layout.pixelWidth + sampleX
                let colorVector = pixels[pixelIndex]
                let color = LUTColor.color(red: colorVector.x,
                                           green: colorVector.y,
                                           blue: colorVector.z)
                lut.setColor(color, r: redIndex, g: greenIndex, b: blueIndex)
            }
        }

        lut.passthroughFileOptions = passthroughOptions(lutSize: layout.cubeSize, bitDepth: bitDepth)
        return lut
    }

    static func read(data: Data) throws -> LUT3D {
        do {
            let image = try ImageBasedLUTUtilities.image(from: data)
            return try read(image: image)
        } catch let utilitiesError as ImageBasedLUTUtilitiesError {
            throw mapUtilitiesError(utilitiesError)
        }
    }

    private struct Layout {
        let cubeSize: Int
        let widthBlocks: Int
        let heightBlocks: Int

        var pixelWidth: Int { widthBlocks * blockSize }
        var pixelHeight: Int { heightBlocks * blockSize }
    }

    private static func layoutForCubeSize(_ cubeSize: Int) -> Layout {
        precondition(cubeSize > 0, "Cube size must be positive")
        let heightBlocks = Int((Double(cubeSize).squareRoot() * Double(cubeSize)).rounded())
        let widthBlocks = Int(ceil(pow(Double(cubeSize), 3.0) / Double(heightBlocks)))
        return Layout(cubeSize: cubeSize,
                      widthBlocks: max(widthBlocks, 1),
                      heightBlocks: max(heightBlocks, 1))
    }

    private static func layoutFromImage(width: Int, height: Int) throws -> Layout {
        let widthBlocks = width / blockSize
        let heightBlocks = height / blockSize
        guard widthBlocks > 0, heightBlocks > 0 else { throw LUTFormatterCMSTestPatternError.invalidDimensions }

        let cubeSizeEstimate = pow(Double(heightBlocks * heightBlocks), 1.0 / 3.0)
        let cubeSize = Int(cubeSizeEstimate.rounded())
        guard cubeSize > 0 else { throw LUTFormatterCMSTestPatternError.invalidDimensions }

        let expectedLayout = layoutForCubeSize(cubeSize)
        guard expectedLayout.widthBlocks == widthBlocks,
              expectedLayout.heightBlocks == heightBlocks else {
            throw LUTFormatterCMSTestPatternError.invalidDimensions
        }

        return expectedLayout
    }

    private static func writePixels(from lut: LUT3D,
                                    layout: Layout,
                                    handler: (_ pixelIndex: Int, _ color: LUTColor) -> Void) {
        let totalEntries = layout.cubeSize * layout.cubeSize * layout.cubeSize
        for yBlock in 0..<layout.heightBlocks {
            for xBlock in 0..<layout.widthBlocks {
                let cubeIndex = yBlock * layout.widthBlocks + xBlock
                let color: LUTColor
                if cubeIndex < totalEntries {
                    let redIndex = cubeIndex % layout.cubeSize
                    let greenIndex = (cubeIndex / layout.cubeSize) % layout.cubeSize
                    let blueIndex = cubeIndex / (layout.cubeSize * layout.cubeSize)
                    color = lut.colorAt(r: redIndex, g: greenIndex, b: blueIndex)
                } else {
                    color = .zeros()
                }

                let xStart = xBlock * blockSize
                let yStart = (layout.heightBlocks - (yBlock + 1)) * blockSize
                for innerY in 0..<blockSize {
                    let rowOffset = (yStart + innerY) * layout.pixelWidth
                    for innerX in 0..<blockSize {
                        let pixelIndex = rowOffset + xStart + innerX
                        handler(pixelIndex, color)
                    }
                }
            }
        }
    }

    private static func passthroughOptions(lutSize: Int, bitDepth: Int) -> [String: Any] {
        [formatterIdentifier: ["lutSize": lutSize, "bitDepth": bitDepth]]
    }

    private static func mapUtilitiesError(_ error: ImageBasedLUTUtilitiesError) -> LUTFormatterCMSTestPatternError {
        switch error {
        case .unsupportedBitDepth:
            return .unsupportedBitDepth
        case .unsupportedImage:
            return .unsupportedImage
        }
    }
}

extension LUTFormatterCMSTestPattern.Options {
    static func from(passthrough options: [String: Any]) -> LUTFormatterCMSTestPattern.Options? {
        guard let formatterOptions = options[LUTFormatterCMSTestPattern.formatterIdentifier] as? [String: Any] else {
            return nil
        }

        if let bitDepth = formatterOptions["bitDepth"] as? Int {
            return .init(bitDepth: bitDepth)
        }
        if let number = formatterOptions["bitDepth"] as? NSNumber {
            return .init(bitDepth: number.intValue)
        }
        return nil
    }
}
