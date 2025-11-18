import XCTest
@testable import CocoaLUTSwift

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

    func testScaledRGBToUnitRangeTargetsChannelExtrema() {
        let lut = makeNonUniformLUT()
        let scaled = lut.scaledRGBTo01()

        let minColor = lut.minimumOutputColor()
        let maxColor = lut.maximumOutputColor()

        for (r, g, b) in [(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 1)] {
            let original = lut.colorAt(r: r, g: g, b: b)
            let remapped = scaled.colorAt(r: r, g: g, b: b)

            let expectedRed = LUTMath.remapNoError(original.red,
                                                    inputLow: minColor.red,
                                                    inputHigh: maxColor.red,
                                                    outputLow: 0,
                                                    outputHigh: 1)
            let expectedGreen = LUTMath.remapNoError(original.green,
                                                      inputLow: minColor.green,
                                                      inputHigh: maxColor.green,
                                                      outputLow: 0,
                                                      outputHigh: 1)
            let expectedBlue = LUTMath.remapNoError(original.blue,
                                                     inputLow: minColor.blue,
                                                     inputHigh: maxColor.blue,
                                                     outputLow: 0,
                                                     outputHigh: 1)

            XCTAssertEqual(remapped.red, expectedRed, accuracy: 1e-9)
            XCTAssertEqual(remapped.green, expectedGreen, accuracy: 1e-9)
            XCTAssertEqual(remapped.blue, expectedBlue, accuracy: 1e-9)
        }

        let scaledMin = scaled.minimumOutputColor()
        let scaledMax = scaled.maximumOutputColor()
        XCTAssertEqual(scaledMin.red, 0, accuracy: 1e-9)
        XCTAssertEqual(scaledMin.green, 0, accuracy: 1e-9)
        XCTAssertEqual(scaledMin.blue, 0, accuracy: 1e-9)
        XCTAssertEqual(scaledMax.red, 1, accuracy: 1e-9)
        XCTAssertEqual(scaledMax.green, 1, accuracy: 1e-9)
        XCTAssertEqual(scaledMax.blue, 1, accuracy: 1e-9)
    }

    func testScaledCurvesToUnitRangeRespectsDiagonal() {
        let lut = makeNonUniformLUT()
        let scaled = lut.scaledCurvesTo01()

        let diagonalColors = (0..<lut.size).map { lut.colorAt(r: $0, g: $0, b: $0) }
        let minValue = diagonalColors.map { $0.minimumValue() }.min()!
        let maxValue = diagonalColors.map { $0.maximumValue() }.max()!

        for coordinate in (0..<lut.size) {
            let original = lut.colorAt(r: coordinate, g: coordinate, b: coordinate)
            let remapped = scaled.colorAt(r: coordinate, g: coordinate, b: coordinate)

            let expectedRed = LUTMath.remapNoError(original.red,
                                                    inputLow: minValue,
                                                    inputHigh: maxValue,
                                                    outputLow: 0,
                                                    outputHigh: 1)
            let expectedGreen = LUTMath.remapNoError(original.green,
                                                      inputLow: minValue,
                                                      inputHigh: maxValue,
                                                      outputLow: 0,
                                                      outputHigh: 1)
            let expectedBlue = LUTMath.remapNoError(original.blue,
                                                     inputLow: minValue,
                                                     inputHigh: maxValue,
                                                     outputLow: 0,
                                                     outputHigh: 1)

            XCTAssertEqual(remapped.red, expectedRed, accuracy: 1e-9)
            XCTAssertEqual(remapped.green, expectedGreen, accuracy: 1e-9)
            XCTAssertEqual(remapped.blue, expectedBlue, accuracy: 1e-9)
            XCTAssertTrue((0...1).contains(remapped.red))
            XCTAssertTrue((0...1).contains(remapped.green))
            XCTAssertTrue((0...1).contains(remapped.blue))
        }
    }

    func testScaledCurvesRGBToUnitRangeRespectsDiagonalChannels() {
        let lut = makeNonUniformLUT()
        let scaled = lut.scaledCurvesRGBTo01()

        let minCurve = scaled.colorAt(r: 0, g: 0, b: 0)
        XCTAssertEqual(minCurve.red, 0, accuracy: 1e-9)
        XCTAssertEqual(minCurve.green, 0, accuracy: 1e-9)
        XCTAssertEqual(minCurve.blue, 0, accuracy: 1e-9)

        let maxCurve = scaled.colorAt(r: 1, g: 1, b: 1)
        XCTAssertEqual(maxCurve.red, 1, accuracy: 1e-9)
        XCTAssertEqual(maxCurve.green, 1, accuracy: 1e-9)
        XCTAssertEqual(maxCurve.blue, 1, accuracy: 1e-9)
    }

    func testScaledLegalToExtendedUsesConstants() {
        var lut = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(LUTColor.color(red: LUTConstants.legalLevelsMin,
                                    green: LUTConstants.legalLevelsMin,
                                    blue: LUTConstants.legalLevelsMin),
                     r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: LUTConstants.legalLevelsMax,
                                    green: LUTConstants.legalLevelsMax,
                                    blue: LUTConstants.legalLevelsMax),
                     r: 1, g: 1, b: 1)

        let scaled = lut.scaledLegalToExtended()
        let minColor = scaled.colorAt(r: 0, g: 0, b: 0)
        XCTAssertEqual(minColor.red, 0, accuracy: 1e-9)
        XCTAssertEqual(minColor.green, 0, accuracy: 1e-9)
        XCTAssertEqual(minColor.blue, 0, accuracy: 1e-9)

        let maxColor = scaled.colorAt(r: 1, g: 1, b: 1)
        XCTAssertEqual(maxColor.red, 1, accuracy: 1e-9)
        XCTAssertEqual(maxColor.green, 1, accuracy: 1e-9)
        XCTAssertEqual(maxColor.blue, 1, accuracy: 1e-9)
    }

    func testScaledExtendedToLegalUsesConstants() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let scaled = lut.scaledExtendedToLegal()

        let minColor = scaled.colorAt(r: 0, g: 0, b: 0)
        XCTAssertEqual(minColor.red, LUTConstants.legalLevelsMin, accuracy: 1e-9)
        XCTAssertEqual(minColor.green, LUTConstants.legalLevelsMin, accuracy: 1e-9)
        XCTAssertEqual(minColor.blue, LUTConstants.legalLevelsMin, accuracy: 1e-9)

        let maxColor = scaled.colorAt(r: 1, g: 1, b: 1)
        XCTAssertEqual(maxColor.red, LUTConstants.legalLevelsMax, accuracy: 1e-9)
        XCTAssertEqual(maxColor.green, LUTConstants.legalLevelsMax, accuracy: 1e-9)
        XCTAssertEqual(maxColor.blue, LUTConstants.legalLevelsMax, accuracy: 1e-9)
    }

    func testCombinedWithSameSizeMatchesSelf() {
        let identity = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let offset = LUTAction.offset(by: LUTColor.color(red: 0.1, green: -0.1, blue: 0.05)).apply(to: identity)

        let combined = identity.combined(with: offset)
        XCTAssertTrue(combined.equals(offset, tolerance: 1e-9))
    }

    func testCombinedWithDifferentSizesUsesSuggestedMaximum() {
        let base = LUT.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let scaled = base.scaledTo01().resized(to: 33)

        let combined = base.combined(with: scaled)
        XCTAssertEqual(combined.size, 33)

        let sampleIndex = 12
        let identityColor = combined.identityColorAt(r: Double(sampleIndex),
                                                     g: Double(sampleIndex),
                                                     b: Double(sampleIndex))
        let intermediate = base.color(at: identityColor)
        let expected = scaled.color(at: intermediate)
        let sample = combined.colorAt(r: sampleIndex, g: sampleIndex, b: sampleIndex)

        XCTAssertEqual(sample.red, expected.red, accuracy: 1e-6)
        XCTAssertEqual(sample.green, expected.green, accuracy: 1e-6)
        XCTAssertEqual(sample.blue, expected.blue, accuracy: 1e-6)
    }
}
