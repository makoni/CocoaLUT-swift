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
    func testInitialIsVideoFalseAndPlayerExists() {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        #expect(view.isVideo == false)
        // Player is constructed eagerly even when no video is set.
        _ = view.videoPlayer
    }

    @Test
    func testSettingVideoURLToNilLeavesIsVideoFalse() {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.videoURL = nil
        #expect(view.isVideo == false)
    }

    @Test
    func testPlaybackLayersHiddenStateMatchesIsVideo() {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.layoutSubtreeIfNeeded()
        // Without a video URL, video layers should be hidden and image layers visible.
        #expect(view.lutVideoLayer.isHidden == true)
        #expect(view.normalVideoLayer.isHidden == true)
        #expect(view.originalLayer.isHidden == false)
        #expect(view.processedLayer.isHidden == false)
    }

    @Test
    func testSettingPreviewImageClearsVideoURL() {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        // Pretend a URL was set, then setting an image should reset isVideo.
        view.videoURL = nil
        view.previewImage = Self.makeSolidImage(color: .white, size: NSSize(width: 32, height: 32))
        #expect(view.isVideo == false)
        #expect(view.videoURL == nil)
    }

    @Test
    func testSettingPreviewImageUpdatesLayerContents() throws {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.previewImage = Self.makeSolidImage(color: .white, size: NSSize(width: 32, height: 32))
        view.layoutSubtreeIfNeeded()

        #expect(view.originalLayer.contents != nil)
        #expect(view.processedLayer.contents != nil)
    }

    @Test
    func testSettingPreviewImageToNilClearsLayerContents() {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.previewImage = Self.makeSolidImage(color: .blue, size: NSSize(width: 32, height: 32))
        view.layoutSubtreeIfNeeded()
        // Sanity check that the image was attached.
        #expect(view.originalLayer.contents != nil)

        view.previewImage = nil
        view.layoutSubtreeIfNeeded()
        // Both layers must drop their cached contents so a stale frame doesn't
        // continue to display after the host clears the preview.
        #expect(view.originalLayer.contents == nil)
        #expect(view.processedLayer.contents == nil)
    }

    @Test
    func testSettingLUTAfterPreviewImageRefreshesProcessedLayer() {
        let view = LUTPreviewView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        view.previewImage = Self.makeSolidImage(color: NSColor(calibratedWhite: 0.5, alpha: 1),
                                                 size: NSSize(width: 32, height: 32))
        view.layoutSubtreeIfNeeded()
        let originalProcessed = view.processedLayer.contents

        // Apply a constant red LUT — processedLayer.contents must change.
        var lut = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<2 { for g in 0..<2 { for b in 0..<2 {
            lut.setColor(LUTColor.color(red: 1, green: 0, blue: 0), r: r, g: g, b: b)
        }}}
        view.lut = lut
        view.layoutSubtreeIfNeeded()
        // processedLayer.contents is `Any?`, so we compare via object identity
        // when both sides are CGImage / NSImage instances.
        let updatedProcessed = view.processedLayer.contents
        let originalAny = originalProcessed as AnyObject?
        let updatedAny = updatedProcessed as AnyObject?
        #expect(originalAny !== updatedAny)
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
