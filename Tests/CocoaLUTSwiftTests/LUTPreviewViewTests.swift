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
        #expect(view.maskAmount == 1.0)
        let maskLayer = try #require(view.processedLayer.mask)
        #expect(abs(maskLayer.frame.width - view.bounds.width) < 0.5)

        view.maskAmount = -0.5
        view.layoutSubtreeIfNeeded()
        #expect(view.maskAmount == 0.0)
        #expect(abs(maskLayer.frame.width - 0.0) < 0.5)
    }

    @Test
    func testSettingPreviewImageUpdatesLayerContents() throws {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.previewImage = Self.makeSolidImage(color: .white, size: NSSize(width: 32, height: 32))
        view.layoutSubtreeIfNeeded()

        #expect(view.originalLayer.contents != nil)
        #expect(view.processedLayer.contents != nil)
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
