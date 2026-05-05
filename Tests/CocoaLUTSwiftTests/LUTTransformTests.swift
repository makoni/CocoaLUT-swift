import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTTransformTests {
    private func makeNonUniformLUT() -> LUT {
        var lut = LUT(size: 2, inputLowerBound: -1, inputUpperBound: 2)
        lut.setColor(LUTColor.color(red: -0.5, green: 0.2, blue: 1.5), r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 2.0, green: -1.0, blue: 0.5), r: 1, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 0.3, green: 1.2, blue: -0.7), r: 0, g: 1, b: 0)
        lut.setColor(LUTColor.color(red: 1.1, green: 0.8, blue: 2.6), r: 1, g: 1, b: 1)
        return lut
    }

    @Test
    func testChangingInputBoundsProducesExpectedIdentity() {
        let original = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let updated = original.changingInputBounds(lower: -0.5, upper: 0.5)

        #expect(abs(updated.inputLowerBound - -0.5) < 1e-9)
        #expect(abs(updated.inputUpperBound - 0.5) < 1e-9)

        let sample = updated.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(sample.red - 0.5) < 1e-9)
        #expect(abs(sample.green - 0.5) < 1e-9)
        #expect(abs(sample.blue - 0.5) < 1e-9)
    }

    @Test
    func testClampedRestrictsValuesToBounds() {
        let lut = makeNonUniformLUT()
        let clamped = lut.clamped(lower: 0, upper: 1)

        let color = clamped.colorAt(r: 1, g: 0, b: 0)
        #expect(abs(color.red - 1) < 1e-9)
        #expect(abs(color.green - 0) < 1e-9)
        #expect(abs(color.blue - 0.5) < 1e-9)
    }

    @Test
    func testRemappingValuesAdjustsRange() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let remapped = lut.remappingValues(inputLow: 0,
                                           inputHigh: 1,
                                           outputLow: -1,
                                           outputHigh: 1,
                                           bounded: false)

        let color = remapped.colorAt(r: 1, g: 0, b: 0)
        #expect(abs(color.red - 1) < 1e-9)
        #expect(abs(color.green - -1) < 1e-9)
        #expect(abs(color.blue - -1) < 1e-9)
    }

    @Test
    func testOffsettingAddsColor() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let offset = LUTColor.color(red: 0.1, green: -0.2, blue: 0.3)
        let adjusted = lut.offsetting(by: offset)

        let color = adjusted.colorAt(r: 0, g: 1, b: 1)
        #expect(abs(color.red - 0.1) < 1e-9)
        #expect(abs(color.green - 0.8) < 1e-9)
        #expect(abs(color.blue - 1.3) < 1e-9)
    }

    @Test
    func testScaledToUnitRangeUsesExtrema() {
        let lut = makeNonUniformLUT()
        let scaled = lut.scaledTo01()

        #expect(scaled.minimumOutputValue() >= 0)
        #expect(scaled.maximumOutputValue() <= 1)

        let minColor = scaled.minimumOutputColor()
        let maxColor = scaled.maximumOutputColor()
        #expect(minColor.minimumValue() >= 0)
        #expect(maxColor.maximumValue() <= 1)
    }

    @Test
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

            #expect(abs(remapped.red - expectedRed) < 1e-9)
            #expect(abs(remapped.green - expectedGreen) < 1e-9)
            #expect(abs(remapped.blue - expectedBlue) < 1e-9)
        }

        let scaledMin = scaled.minimumOutputColor()
        let scaledMax = scaled.maximumOutputColor()
        #expect(abs(scaledMin.red - 0) < 1e-9)
        #expect(abs(scaledMin.green - 0) < 1e-9)
        #expect(abs(scaledMin.blue - 0) < 1e-9)
        #expect(abs(scaledMax.red - 1) < 1e-9)
        #expect(abs(scaledMax.green - 1) < 1e-9)
        #expect(abs(scaledMax.blue - 1) < 1e-9)
    }

    @Test
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

            #expect(abs(remapped.red - expectedRed) < 1e-9)
            #expect(abs(remapped.green - expectedGreen) < 1e-9)
            #expect(abs(remapped.blue - expectedBlue) < 1e-9)
            #expect((0...1).contains(remapped.red))
            #expect((0...1).contains(remapped.green))
            #expect((0...1).contains(remapped.blue))
        }
    }

    @Test
    func testScaledCurvesRGBToUnitRangeRespectsDiagonalChannels() {
        let lut = makeNonUniformLUT()
        let scaled = lut.scaledCurvesRGBTo01()

        let minCurve = scaled.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(minCurve.red - 0) < 1e-9)
        #expect(abs(minCurve.green - 0) < 1e-9)
        #expect(abs(minCurve.blue - 0) < 1e-9)

        let maxCurve = scaled.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(maxCurve.red - 1) < 1e-9)
        #expect(abs(maxCurve.green - 1) < 1e-9)
        #expect(abs(maxCurve.blue - 1) < 1e-9)
    }

    @Test
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
        #expect(abs(minColor.red - 0) < 1e-9)
        #expect(abs(minColor.green - 0) < 1e-9)
        #expect(abs(minColor.blue - 0) < 1e-9)

        let maxColor = scaled.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(maxColor.red - 1) < 1e-9)
        #expect(abs(maxColor.green - 1) < 1e-9)
        #expect(abs(maxColor.blue - 1) < 1e-9)
    }

    @Test
    func testScaledExtendedToLegalUsesConstants() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let scaled = lut.scaledExtendedToLegal()

        let minColor = scaled.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(minColor.red - LUTConstants.legalLevelsMin) < 1e-9)
        #expect(abs(minColor.green - LUTConstants.legalLevelsMin) < 1e-9)
        #expect(abs(minColor.blue - LUTConstants.legalLevelsMin) < 1e-9)

        let maxColor = scaled.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(maxColor.red - LUTConstants.legalLevelsMax) < 1e-9)
        #expect(abs(maxColor.green - LUTConstants.legalLevelsMax) < 1e-9)
        #expect(abs(maxColor.blue - LUTConstants.legalLevelsMax) < 1e-9)
    }

    @Test
    func testCombinedWithSameSizeMatchesSelf() {
        let identity = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let offset = LUTAction.offset(by: LUTColor.color(red: 0.1, green: -0.1, blue: 0.05)).apply(to: identity)

        let combined = identity.combined(with: offset)
        #expect(combined.equals(offset, tolerance: 1e-9))
    }

    @Test
    func testCombinedWithDifferentSizesUsesSuggestedMaximum() {
        let base = LUT.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let scaled = base.scaledTo01().resized(to: 33)

        let combined = base.combined(with: scaled)
        #expect(combined.size == 33)

        let sampleIndex = 12
        let identityColor = combined.identityColorAt(r: Double(sampleIndex),
                                                     g: Double(sampleIndex),
                                                     b: Double(sampleIndex))
        let intermediate = base.color(at: identityColor)
        let expected = scaled.color(at: intermediate)
        let sample = combined.colorAt(r: sampleIndex, g: sampleIndex, b: sampleIndex)

        #expect(abs(sample.red - expected.red) < 1e-6)
        #expect(abs(sample.green - expected.green) < 1e-6)
        #expect(abs(sample.blue - expected.blue) < 1e-6)
    }
}
