import Testing
@testable import CocoaLUTSwift

#if canImport(CoreImage)
import CoreImage
import CoreGraphics
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor

@Suite
struct LUTPlatformGlueTests {
    #if canImport(CoreImage)
    @Test
    func testCoreImageFilterClampsDimension() {
        let lut = LUT.identity(size: 72, inputLowerBound: 0, inputUpperBound: 1)
        guard let filter = try? lut.coreImageFilter() else {
            XCTFail("Expected Core Image filter")
            return
        }
        let dimension = filter.value(forKey: "inputCubeDimension") as? NSNumber
        XCTAssertEqual(dimension?.intValue, 64)
    }

    @Test
    func testCoreImageFilterDataMatchesLUT() {
        var lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.1, green: 0.2, blue: 0.3), r: 0, g: 0, b: 0)
        lut.setColor(.color(red: 0.4, green: 0.5, blue: 0.6), r: 1, g: 0, b: 0)

        guard let filter = try? lut.coreImageFilter() else {
            XCTFail("Expected Core Image filter")
            return
        }
        guard let data = filter.value(forKey: "inputCubeData") as? Data else {
            XCTFail("Missing cube data")
            return
        }
        let floats = data.withUnsafeBytes { buffer -> [Float] in
            Array(buffer.bindMemory(to: Float.self))
        }
        XCTAssertGreaterThan(floats.count, 4)
        XCTAssertEqual(floats[0], 0.1, accuracy: 1e-6)
        XCTAssertEqual(floats[1], 0.2, accuracy: 1e-6)
        XCTAssertEqual(floats[2], 0.3, accuracy: 1e-6)
        XCTAssertEqual(floats[3], 1.0, accuracy: 1e-6)
    }

    @Test
    func testProcessCIImageAppliesTransform() {
        let lut = LUT.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
            .remappingValues(inputLow: 0, inputHigh: 1, outputLow: 1, outputHigh: 0)

        let color = CIColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
        let input = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        guard let outputImage = lut.process(ciImage: input) else {
            XCTFail("Expected processed CIImage")
            return
        }

        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            XCTFail("Failed to render output image")
            return
        }
        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            XCTFail("Missing pixel data")
            return
        }
        let bytes = CFDataGetBytePtr(pixelData)
        let red = Double(bytes![0]) / 255.0
        let green = Double(bytes![1]) / 255.0
        let blue = Double(bytes![2]) / 255.0

        XCTAssertEqual(red, 0.75, accuracy: 0.02)
        XCTAssertEqual(green, 0.5, accuracy: 0.02)
        XCTAssertEqual(blue, 0.25, accuracy: 0.02)
    }
    #endif

    #if canImport(AppKit)
    @Test
    func testProcessNSImageUsesCoreImagePath() {
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.6, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        let lut = LUT.identity(size: 33, inputLowerBound: 0, inputUpperBound: 1)
            .remappingValues(inputLow: 0, inputHigh: 1, outputLow: 1, outputHigh: 0)

        guard let processed = lut.process(nsImage: image, renderPath: .coreImage) else {
            XCTFail("Expected processed NSImage")
            return
        }
        guard let rep = processed.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              let color = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB) else {
            XCTFail("Unable to sample processed image")
            return
        }

        XCTAssertEqual(color.redComponent, 0.8, accuracy: 0.05)
        XCTAssertEqual(color.greenComponent, 0.6, accuracy: 0.05)
        XCTAssertEqual(color.blueComponent, 0.4, accuracy: 0.05)
    }
    #endif
}
