import XCTest
@testable import CocoaLUTSwift

#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class GPUImageCocoaLUTFilterTests: XCTestCase {
    func testLookupImageDimensionsMatchUnwrappedTextureLayout() throws {
        let size = 4
        let lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        let filter = try GPUImageCocoaLUTFilter(lut: lut)
        let image = filter.lookupImage
        XCTAssertEqual(image.width, size * size)
        XCTAssertEqual(image.height, size)
    }

    func testLookupImageFirstPixelMatchesIdentityLUT() throws {
        let size = 4
        var lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.25, green: 0.5, blue: 0.75), r: 1, g: 0, b: 0)
        let filter = try GPUImageCocoaLUTFilter(lut: lut)
        let image = filter.lookupImage
        let pixels = try ImageBasedLUTUtilities.normalizedPixelData(from: image)
        XCTAssertEqual(pixels.count, image.width * image.height)

        // Layout: index = g * width + (b * size + r)
        let indexR100 = 1 // g=0, b=0, r=1
        let colorR100 = pixels[indexR100]
    XCTAssertEqual(colorR100.x, 0.25, accuracy: 0.002)
    XCTAssertEqual(colorR100.y, 0.5, accuracy: 0.002)
    XCTAssertEqual(colorR100.z, 0.75, accuracy: 0.002)
    }

    func testLUTConvenienceInitializerProducesFilter() throws {
        let lut = LUT.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let filter = try lut.gpuImageLookupFilter(bitDepth: 8)
        XCTAssertEqual(filter.lookupImage.width, 9)
        XCTAssertEqual(filter.lookupImage.height, 3)
    }
}
