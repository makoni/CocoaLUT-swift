#if canImport(AppKit)
import AppKit
import Testing
@testable import CocoaLUTSwift

@MainActor

@Suite(.serialized)
struct LUT1DGraphViewTests {
    @Test
    func testGraphViewProducesDrawableOutput() throws {
        var lut = LUT1D.uniformCurve(size: 16, inputLowerBound: 0, inputUpperBound: 1)
        for index in 0..<lut.size {
            let value = Double(index) / Double(lut.size - 1)
            lut.setColor(LUTColor.color(red: value, green: value * value, blue: sqrt(value)), index: index)
        }

        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        view.lut = lut
        view.layoutSubtreeIfNeeded()

        let representation = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        let pngData = representation.representation(using: .png, properties: [:])
        #expect(pngData != nil)
    }

    @Test
    func testTrackingAreaInstalledOnView() {
        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        #expect(view.trackingAreas.count >= 1)
        #expect(view.mouseIsIn == false)
    }

    @Test
    func testLUTDidChangeCallbackFiresOnLUTSet() {
        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        var fired = 0
        view.onLUTDidChange = { _ in fired += 1 }
        view.lut = LUT1D.uniformCurve(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        #expect(fired == 1)
        view.lut = nil
        #expect(fired == 1)  // setting nil doesn't fire the change callback.
    }

    @Test
    func testIndexLookupReturnsExpectedColors() {
        var lut = LUT1D.uniformCurve(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        for i in 0..<lut.size {
            let v = Double(i) / Double(lut.size - 1)
            // Curve with a known shape: red = v^2, green = v, blue = 1 - v.
            lut.setColor(LUTColor.color(red: v * v, green: v, blue: 1 - v), index: i)
        }

        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        view.lut = lut
        view.mousePoint = NSPoint(x: 50, y: 50)  // halfway across — inputValue ≈ 0.5

        let lookup = view.lookupColors(at: view.mousePoint)
        #expect(lookup != nil)
        if let (output, identity) = lookup {
            // Halfway: identity should be (0.5, 0.5, 0.5).
            #expect(abs(identity.red - 0.5) < 0.05)
            #expect(abs(identity.green - 0.5) < 0.05)
            #expect(abs(identity.blue - 0.5) < 0.05)
            // Output: red ≈ 0.25, green ≈ 0.5, blue ≈ 0.5
            #expect(abs(output.red - 0.25) < 0.05)
            #expect(abs(output.green - 0.5) < 0.05)
            #expect(abs(output.blue - 0.5) < 0.05)
        }
    }

    @Test
    func testInterpolationDisplayName() {
        #expect(LUT1DGraphView.Interpolation.linear.displayName == "Linear")
    }

    @Test
    func testRangeUpdatesWhenSettingLUT() {
        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        #expect(view.minimumOutputValue == 0)
        #expect(view.maximumOutputValue == 1)

        var lut = LUT1D.uniformCurve(size: 4, inputLowerBound: -1, inputUpperBound: 2)
        lut.setColor(LUTColor.color(red: -0.5, green: 1.5, blue: 0.25), index: 0)
        view.lut = lut

        #expect(view.minimumOutputValue <= -0.5)
        #expect(view.maximumOutputValue >= 1.5)
    }
}
#endif
