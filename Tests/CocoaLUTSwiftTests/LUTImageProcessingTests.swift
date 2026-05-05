import XCTest
@testable import CocoaLUTSwift

#if canImport(AppKit)
import AppKit

final class LUTImageProcessingTests: XCTestCase {
    @MainActor
    func testCoreImageAndDirectRenderingMatch() throws {
        #if canImport(CoreImage)
        var lut3D = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut3D.loop { r, g, b in
            let color = lut3D.colorAt(r: r, g: g, b: b)
            let swapped = LUTColor(red: color.blue, green: color.green, blue: color.red)
            lut3D.setColor(swapped, r: r, g: g, b: b)
        }

        let lut = lut3D.asLUT()
        let testImage = makeTestImage()

        let coreImageResult = try XCTUnwrap(lut.process(nsImage: testImage, renderPath: .coreImage))
        let directResult = try XCTUnwrap(lut.process(nsImage: testImage, renderPath: .direct))

        try assertImagesEqual(coreImageResult, directResult)
        #else
        throw XCTSkip("Core Image not available")
        #endif
    }
}

private extension LUTImageProcessingTests {
    func makeTestImage() -> NSImage {
        let size = NSSize(width: 2, height: 2)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()

        NSColor.green.setFill()
        NSRect(x: 1, y: 0, width: 1, height: 1).fill()

        NSColor.blue.setFill()
        NSRect(x: 0, y: 1, width: 1, height: 1).fill()

        NSColor.white.setFill()
        NSRect(x: 1, y: 1, width: 1, height: 1).fill()

        return image
    }

    func assertImagesEqual(_ lhs: NSImage, _ rhs: NSImage, tolerance: Double = 1e-3) throws {
        let lhsPixels = try pixelData(from: lhs)
        let rhsPixels = try pixelData(from: rhs)

        XCTAssertEqual(lhsPixels.count, rhsPixels.count, "Pixel counts differ")
        for (index, pair) in zip(lhsPixels.indices, zip(lhsPixels, rhsPixels)) {
            let (lhsPixel, rhsPixel) = pair
            if abs(lhsPixel - rhsPixel) > tolerance {
                print("Pixel \(index): lhs=\(lhsPixel) rhs=\(rhsPixel)")
            }
            XCTAssertLessThanOrEqual(abs(lhsPixel - rhsPixel), tolerance, "Pixel mismatch exceeds tolerance")
        }
    }

    func pixelData(from image: NSImage) throws -> [Double] {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw XCTSkip("Unable to extract bitmap representation")
        }

        var samples: [Double] = []
        samples.reserveCapacity(bitmap.pixelsHigh * bitmap.pixelsWide * 3)

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                samples.append(Double(color.redComponent))
                samples.append(Double(color.greenComponent))
                samples.append(Double(color.blueComponent))
            }
        }

        return samples
    }
}

#endif