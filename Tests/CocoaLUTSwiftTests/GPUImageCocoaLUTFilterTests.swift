import Testing
@testable import CocoaLUTSwift

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@Suite(.serialized)
struct GPUImageCocoaLUTFilterTests {
    @Test
    func testLookupImageDimensionsMatchUnwrappedTextureLayout() throws {
        let size = 4
        let lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        let filter = try GPUImageCocoaLUTFilter(lut: lut)
        let image = filter.lookupImage
        #expect(image.width == size * size)
        #expect(image.height == size)
    }

    @Test
    func testLookupImageFirstPixelMatchesIdentityLUT() throws {
        let size = 4
        var lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.25, green: 0.5, blue: 0.75), r: 1, g: 0, b: 0)
        let filter = try GPUImageCocoaLUTFilter(lut: lut)
        let image = filter.lookupImage
        let pixels = try ImageBasedLUTUtilities.normalizedPixelData(from: image)
        #expect(pixels.count == image.width * image.height)

        // Layout: index = g * width + (b * size + r)
        let indexR100 = 1 // g=0, b=0, r=1
        let colorR100 = pixels[indexR100]
        #expect(abs(colorR100.x - 0.25) < 0.002)
        #expect(abs(colorR100.y - 0.5) < 0.002)
        #expect(abs(colorR100.z - 0.75) < 0.002)
    }

    @Test
    func testLUTConvenienceInitializerProducesFilter() throws {
        let lut = LUT.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let filter = try lut.gpuImageLookupFilter(bitDepth: 8)
        #expect(filter.lookupImage.width == 9)
        #expect(filter.lookupImage.height == 3)
    }
}
