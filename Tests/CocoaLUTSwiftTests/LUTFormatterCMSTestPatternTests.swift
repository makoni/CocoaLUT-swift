#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CocoaLUT_swift

@Suite final class LUTFormatterCMSTestPatternTests {
    @Test func imageLayoutMatchesSpecification() throws {
        let size = 9
        let lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)

        let image = try LUTFormatterCMSTestPattern.image(from: lut)
        let layout = try unwrapLayout(width: image.width, height: image.height)

        #expect(layout.cubeSize == size)
        #expect(layout.pixelWidth == image.width)
        #expect(layout.pixelHeight == image.height)

        // Sample a representative pixel and verify it matches the LUT entry.
        let sampleR = size / 2
        let sampleG = size / 3
        let sampleB = size / 4
        let expectedColor = lut.colorAt(r: sampleR, g: sampleG, b: sampleB)

        let blockIndex = sampleB * size * size + sampleG * size + sampleR
        let xBlock = blockIndex % layout.widthBlocks
        let yBlock = blockIndex / layout.widthBlocks
        let sampleX = xBlock * 7
        let sampleY = (layout.heightBlocks - (yBlock + 1)) * 7

        let pixelData = try ImageBasedLUTUtilities.normalizedPixelData(from: image)
        let pixel = pixelData[sampleY * layout.pixelWidth + sampleX]
        let decodedColor = LUTColor.color(red: pixel.x, green: pixel.y, blue: pixel.z)

        #expect(decodedColor.isApproximatelyEqual(to: expectedColor, tolerance: 1e-2))
    }

    @Test func pngRoundTrip() throws {
        let size = 7
        var lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(LUTColor.color(red: 0.12, green: 0.34, blue: 0.56), r: 1, g: 2, b: 3)

        let data = try LUTFormatterCMSTestPattern.pngData(from: lut)
        #expect(!data.isEmpty)

        let decoded = try LUTFormatterCMSTestPattern.read(data: data)
        #expect(decoded.size == lut.size)

        let sample = decoded.colorAt(r: 1, g: 2, b: 3)
        #expect(sample.isApproximatelyEqual(to: LUTColor.color(red: 0.12, green: 0.34, blue: 0.56), tolerance: 1e-2))

        let passthrough = decoded.passthroughFileOptions[LUTFormatterCMSTestPattern.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["bitDepth"] as? Int == 8)
        #expect(passthrough?["lutSize"] as? Int == size)
        #expect(passthrough?["fileTypeVariant"] as? String == "TIFF")
    }

    #if canImport(AppKit)
    @Test
    @MainActor func nsImageRoundTrip() throws {
        var lut = LUT3D.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let coordinate = (r: 2, g: 3, b: 4)
        let reference = LUTColor.color(red: 0.75, green: 0.5, blue: 0.25)
        lut.setColor(reference, r: coordinate.r, g: coordinate.g, b: coordinate.b)

        let nsImage = try LUTFormatterCMSTestPattern.nsImage(from: lut)
        let decoded = try LUTFormatterCMSTestPattern.read(nsImage: nsImage)

        #expect(decoded.size == lut.size)
        let sample = decoded.colorAt(r: coordinate.r, g: coordinate.g, b: coordinate.b)
        #expect(sample.isApproximatelyEqual(to: reference, tolerance: 1e-2))
    }
    #endif

    private func unwrapLayout(width: Int, height: Int) throws -> Layout {
        try Layout(width: width, height: height)
    }

    private struct Layout {
        let cubeSize: Int
        let widthBlocks: Int
        let heightBlocks: Int
        let pixelWidth: Int
        let pixelHeight: Int

        init(width: Int, height: Int) throws {
            let widthBlocks = width / 7
            let heightBlocks = height / 7
            #expect(widthBlocks > 0 && heightBlocks > 0)

            let cubeSizeEstimate = pow(Double(heightBlocks * heightBlocks), 1.0 / 3.0)
            let cubeSize = Int(cubeSizeEstimate.rounded())
            let expectedHeightBlocks = Int((Double(cubeSize).squareRoot() * Double(cubeSize)).rounded())
            let expectedWidthBlocks = Int(ceil(pow(Double(cubeSize), 3.0) / Double(expectedHeightBlocks)))

            #expect(expectedHeightBlocks == heightBlocks)
            #expect(expectedWidthBlocks == widthBlocks)

            self.cubeSize = cubeSize
            self.widthBlocks = widthBlocks
            self.heightBlocks = heightBlocks
            self.pixelWidth = width
            self.pixelHeight = height
        }
    }
}

private extension LUTColor {
    func isApproximatelyEqual(to other: LUTColor, tolerance: Double) -> Bool {
        abs(red - other.red) <= tolerance &&
        abs(green - other.green) <= tolerance &&
        abs(blue - other.blue) <= tolerance
    }
}
#endif
