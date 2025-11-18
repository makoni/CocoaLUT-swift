#if canImport(AppKit)
import AppKit
import Testing
@testable import CocoaLUTSwift

@MainActor

@Suite
struct LUTPreviewViewTests {
    @Test
    func testMaskAmountClampsAndUpdatesLayout() throws {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))
        view.maskAmount = 1.5
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.maskAmount, 1.0)
        let maskLayer = try XCTUnwrap(view.processedLayer.mask)
        XCTAssertEqual(maskLayer.frame.width, view.bounds.width, accuracy: 0.5)

        view.maskAmount = -0.5
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.maskAmount, 0.0)
        XCTAssertEqual(maskLayer.frame.width, 0.0, accuracy: 0.5)
    }

    @Test
    func testSettingPreviewImageUpdatesLayerContents() throws {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.previewImage = Self.makeSolidImage(color: .white, size: NSSize(width: 32, height: 32))
        view.layoutSubtreeIfNeeded()

        XCTAssertNotNil(view.originalLayer.contents)
        XCTAssertNotNil(view.processedLayer.contents)
    }

    private static func makeSolidImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        return image
    }
}
#endif
