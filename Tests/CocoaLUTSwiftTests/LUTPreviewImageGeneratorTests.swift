#if canImport(AppKit)
import AppKit
import Testing
@testable import CocoaLUTSwift

@MainActor

@Suite
struct LUTPreviewImageGeneratorTests {
    @Test
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
        let preview = try #require(generator.render(from: inputImage, targetSize: CGSize(width: 30, height: 30)))
        #expect(abs(preview.size.width - 30) < 0.5)
        #expect(abs(preview.size.height - 30) < 0.5)

        let bitmap = try #require(preview.bitmapImageRep())
        let lowerSample = bitmap.colorAt(x: 1, y: 1)
        let upperSample = bitmap.colorAt(x: bitmap.pixelsWide - 2, y: bitmap.pixelsHigh - 2)
        #expect(lowerSample != nil)
        #expect(upperSample != nil)
        if let lower = lowerSample, let upper = upperSample {
            #expect(lower != upper, "Masked region should differ from original content")
        }
    }

    @Test
    func testDiagonalSplitMatchesGoldenSnapshot() throws {
        // Uniform mid-grey input. Identity LUT replaced with a constant red mapping
        // so the upper-left triangle (masked region) renders red and the lower-right
        // triangle (unmasked) renders the original mid-grey.
        let inputImage = Self.makeSolidImage(color: NSColor(calibratedWhite: 0.5, alpha: 1),
                                             size: NSSize(width: 40, height: 40))
        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    lut.setColor(LUTColor.color(red: 1, green: 0, blue: 0), r: r, g: g, b: b)
                }
            }
        }

        let generator = LUTPreviewImageGenerator(lut: lut)
        let preview = try #require(generator.render(from: inputImage, targetSize: CGSize(width: 40, height: 40)))
        let bitmap = try #require(preview.bitmapImageRep())

        // NSBitmapImageRep coords: y=0 is the top. The mask triangle (drawn with
        // y-up Cocoa coords) covers the upper-left half, which in bitmap coords is
        // the upper-left triangle (small x, small y).

        // Upper-left triangle (masked → LUT-processed → red).
        let masked = try #require(bitmap.colorAt(x: 4, y: 4))
        #expect(masked.redComponent > 0.7)
        #expect(masked.greenComponent < 0.3)
        #expect(masked.blueComponent < 0.3)

        // Lower-right triangle (unmasked → original mid-grey).
        let unmasked = try #require(bitmap.colorAt(x: bitmap.pixelsWide - 4,
                                                    y: bitmap.pixelsHigh - 4))
        #expect(abs(unmasked.redComponent - 0.5) < 0.15)
        #expect(abs(unmasked.greenComponent - 0.5) < 0.15)
        #expect(abs(unmasked.blueComponent - 0.5) < 0.15)
    }

    @Test
    func testRenderReturnsNilForZeroTargetSize() {
        let lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let generator = LUTPreviewImageGenerator(lut: lut)
        let image = Self.makeSolidImage(color: .red, size: NSSize(width: 32, height: 32))
        // Zero target ⇒ scaled size is 0×0 ⇒ guard returns nil rather than
        // throwing or rendering an empty bitmap that would crash downstream.
        #expect(generator.render(from: image, targetSize: CGSize(width: 0, height: 0)) == nil)
    }

    @Test
    func testRenderHandlesNonSquareAspectRatio() throws {
        let lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let generator = LUTPreviewImageGenerator(lut: lut)
        let image = Self.makeSolidImage(color: NSColor(calibratedWhite: 0.5, alpha: 1),
                                         size: NSSize(width: 320, height: 90))
        let preview = try #require(generator.render(from: image, targetSize: CGSize(width: 64, height: 64)))
        // Aspect-fit scaling should preserve 32:9 ratio inside a 64-square box —
        // a square output would mean we overflowed onto the unused area.
        #expect(preview.size.width >= preview.size.height)
        #expect(abs(preview.size.width / preview.size.height - 320.0 / 90.0) < 0.05)
    }

    @Test
    func testIdentityLUTRenderProducesSymmetricSplit() throws {
        // Identity LUT means processed = base, so both halves of the diagonal
        // mask should be visually identical (modulo the 50% alpha diagonal
        // stroke that overdraws the line itself).
        let identityLUT = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let generator = LUTPreviewImageGenerator(lut: identityLUT)
        let image = Self.makeSolidImage(color: NSColor(calibratedWhite: 0.5, alpha: 1),
                                         size: NSSize(width: 40, height: 40))
        let preview = try #require(generator.render(from: image, targetSize: CGSize(width: 40, height: 40)))
        let bitmap = try #require(preview.bitmapImageRep())
        let masked = try #require(bitmap.colorAt(x: 4, y: 4))
        let unmasked = try #require(bitmap.colorAt(x: bitmap.pixelsWide - 4, y: bitmap.pixelsHigh - 4))
        #expect(abs(masked.redComponent - unmasked.redComponent) < 0.05)
        #expect(abs(masked.greenComponent - unmasked.greenComponent) < 0.05)
        #expect(abs(masked.blueComponent - unmasked.blueComponent) < 0.05)
    }

    private static func makeSolidImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        return image
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
