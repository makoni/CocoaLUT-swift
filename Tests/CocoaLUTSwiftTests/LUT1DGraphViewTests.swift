#if canImport(AppKit)
import AppKit
import XCTest
@testable import CocoaLUT_swift

final class LUT1DGraphViewTests: XCTestCase {
    @MainActor
    func testGraphViewProducesDrawableOutput() throws {
        var lut = LUT1D.uniformCurve(size: 16, inputLowerBound: 0, inputUpperBound: 1)
        for index in 0..<lut.size {
            let value = Double(index) / Double(lut.size - 1)
            lut.setColor(LUTColor.color(red: value, green: value * value, blue: sqrt(value)), index: index)
        }

        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        view.lut = lut
        view.layoutSubtreeIfNeeded()

        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        let pngData = representation.representation(using: .png, properties: [:])
        XCTAssertNotNil(pngData)
    }

    func testRangeUpdatesWhenSettingLUT() {
        let view = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(view.minimumOutputValue, 0)
        XCTAssertEqual(view.maximumOutputValue, 1)

        var lut = LUT1D.uniformCurve(size: 4, inputLowerBound: -1, inputUpperBound: 2)
        lut.setColor(LUTColor.color(red: -0.5, green: 1.5, blue: 0.25), index: 0)
        view.lut = lut

        XCTAssertLessThanOrEqual(view.minimumOutputValue, -0.5)
        XCTAssertGreaterThanOrEqual(view.maximumOutputValue, 1.5)
    }
}
#endif
