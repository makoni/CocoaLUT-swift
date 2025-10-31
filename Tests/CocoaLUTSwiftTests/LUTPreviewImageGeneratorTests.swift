#if canImport(AppKit)
import AppKit
import XCTest
@testable import CocoaLUT_swift

@MainActor
final class LUTPreviewImageGeneratorTests: XCTestCase {
    func testGeneratesMaskedPreviewImage() throws {
        let inputImage = Self.makeGradientImage(size: NSSize(width: 40, height: 40))
        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    lut.setColor(LUTColor.color(red: 0.8, green: 0.1, blue: 0.1), r: r, g: g, b: b)
                }
            }
        }

        let generator = LUTPreviewImageGenerator(lut: lut)
        let preview = try XCTUnwrap(generator.render(from: inputImage, targetSize: CGSize(width: 30, height: 30)))
        XCTAssertEqual(preview.size.width, 30, accuracy: 0.5)
        XCTAssertEqual(preview.size.height, 30, accuracy: 0.5)

        let bitmap = try XCTUnwrap(preview.bitmapImageRep())
        let lowerSample = bitmap.colorAt(x: 1, y: 1)
        let upperSample = bitmap.colorAt(x: bitmap.pixelsWide - 2, y: bitmap.pixelsHigh - 2)
        XCTAssertNotNil(lowerSample)
        XCTAssertNotNil(upperSample)
        if let lower = lowerSample, let upper = upperSample {
            XCTAssertNotEqual(lower, upper, "Masked region should differ from original content")
        }
    }

    private static func makeGradientImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let gradient = NSGradient(colors: [
            NSColor.red,
            NSColor.green,
            NSColor.blue
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        return image
    }
}

private extension NSImage {
    func bitmapImageRep() -> NSBitmapImageRep? {
        if let bitmap = representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return bitmap
        }
        guard let data = tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else {
            return nil
        }
        return bitmap
    }
}
#endif
