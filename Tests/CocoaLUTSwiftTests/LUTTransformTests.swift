import XCTest
@testable import CocoaLUT_swift

final class LUTTransformTests: XCTestCase {
    private func makeNonUniformLUT() -> LUT {
        var lut = LUT(size: 2, inputLowerBound: -1, inputUpperBound: 2)
        lut.setColor(LUTColor.color(red: -0.5, green: 0.2, blue: 1.5), r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 2.0, green: -1.0, blue: 0.5), r: 1, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 0.3, green: 1.2, blue: -0.7), r: 0, g: 1, b: 0)
        lut.setColor(LUTColor.color(red: 1.1, green: 0.8, blue: 2.6), r: 1, g: 1, b: 1)
        return lut
    }

    func testChangingInputBoundsProducesExpectedIdentity() {
        let original = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let updated = original.changingInputBounds(lower: -0.5, upper: 0.5)

        XCTAssertEqual(updated.inputLowerBound, -0.5, accuracy: 1e-9)
        XCTAssertEqual(updated.inputUpperBound, 0.5, accuracy: 1e-9)

        let sample = updated.colorAt(r: 1, g: 1, b: 1)
        XCTAssertEqual(sample.red, 0.5, accuracy: 1e-9)
        XCTAssertEqual(sample.green, 0.5, accuracy: 1e-9)
        XCTAssertEqual(sample.blue, 0.5, accuracy: 1e-9)
    }

    func testClampedRestrictsValuesToBounds() {
        let lut = makeNonUniformLUT()
        let clamped = lut.clamped(lower: 0, upper: 1)

        let color = clamped.colorAt(r: 1, g: 0, b: 0)
        XCTAssertEqual(color.red, 1, accuracy: 1e-9)
        XCTAssertEqual(color.green, 0, accuracy: 1e-9)
        XCTAssertEqual(color.blue, 0.5, accuracy: 1e-9)
    }

    func testRemappingValuesAdjustsRange() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let remapped = lut.remappingValues(inputLow: 0,
                                           inputHigh: 1,
                                           outputLow: -1,
                                           outputHigh: 1,
                                           bounded: false)

        let color = remapped.colorAt(r: 1, g: 0, b: 0)
        XCTAssertEqual(color.red, 1, accuracy: 1e-9)
        XCTAssertEqual(color.green, -1, accuracy: 1e-9)
        XCTAssertEqual(color.blue, -1, accuracy: 1e-9)
    }

    func testOffsettingAddsColor() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let offset = LUTColor.color(red: 0.1, green: -0.2, blue: 0.3)
        let adjusted = lut.offsetting(by: offset)

        let color = adjusted.colorAt(r: 0, g: 1, b: 1)
        XCTAssertEqual(color.red, 0.1, accuracy: 1e-9)
        XCTAssertEqual(color.green, 0.8, accuracy: 1e-9)
        XCTAssertEqual(color.blue, 1.3, accuracy: 1e-9)
    }

    func testScaledToUnitRangeUsesExtrema() {
        let lut = makeNonUniformLUT()
        let scaled = lut.scaledTo01()

        XCTAssertGreaterThanOrEqual(scaled.minimumOutputValue(), 0)
        XCTAssertLessThanOrEqual(scaled.maximumOutputValue(), 1)

        let minColor = scaled.minimumOutputColor()
        let maxColor = scaled.maximumOutputColor()
        XCTAssertGreaterThanOrEqual(minColor.minimumValue(), 0)
        XCTAssertLessThanOrEqual(maxColor.maximumValue(), 1)
    }
}
