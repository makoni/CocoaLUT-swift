#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
import Testing
@testable import CocoaLUTSwift

@Suite final class LUTFormatterHaldCLUTTests {
    @Test func roundTripIdentityLUT() throws {
    let size = 16
    let lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        let image = try LUTFormatterHaldCLUT.image(from: lut)
        #expect(image.width == image.height)

    let decoded = try LUTFormatterHaldCLUT.read(image: image)
        #expect(decoded.size == lut.size)

    let passthrough = decoded.passthroughFileOptions[LUTFormatterHaldCLUT.formatterIdentifier] as? [String: Any]
    #expect(passthrough?["bitDepth"] as? Int == 8)
    #expect(passthrough?["lutSize"] as? Int == size)
    #expect(passthrough?["fileTypeVariant"] as? String == "TIFF")

        // Validate representative samples across the lattice.
    let step = max(1, size / 4)
    let sampleCoordinates = stride(from: 0, through: size - 1, by: step)
        for r in sampleCoordinates {
            for g in sampleCoordinates {
                for b in sampleCoordinates {
                    let original = lut.colorAt(r: r, g: g, b: b)
                    let roundTripped = decoded.colorAt(r: r, g: g, b: b)
                    #expect(original.isApproximatelyEqual(to: roundTripped, tolerance: 1e-3))
                }
            }
        }
    }

    @Test func pngDataRoundTrip() throws {
        let size = 16
    var lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(LUTColor.color(red: 0.2, green: 0.4, blue: 0.6), r: size / 2, g: size / 3, b: size / 4)

        let data = try LUTFormatterHaldCLUT.pngData(from: lut)
        #expect(!data.isEmpty)

        let decoded = try LUTFormatterHaldCLUT.read(data: data)
        let sampleColor = decoded.colorAt(r: size / 2, g: size / 3, b: size / 4)
        #expect(sampleColor.isApproximatelyEqual(to: LUTColor.color(red: 0.2, green: 0.4, blue: 0.6), tolerance: 1e-2))

        let passthrough = decoded.passthroughFileOptions[LUTFormatterHaldCLUT.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["bitDepth"] as? Int == 8)
        #expect(passthrough?["fileTypeVariant"] as? String == "TIFF")
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
