import Testing
@testable import CocoaLUTSwift

// Boundary-condition coverage for the core types: minimum sizes,
// non-reversible curves, sanitization of pathological numeric inputs,
// and fast-vs-slow paths in combined().
@Suite
struct LUTEdgeCasesTests {

    // MARK: - LUTColor sanitization

    @Test
    func testLUTColorSanitizesNaNToZero() {
        let color = LUTColor(red: .nan, green: 0.5, blue: -.nan)
        #expect(color.red == 0)
        #expect(color.green == 0.5)
        #expect(color.blue == 0)
    }

    @Test
    func testLUTColorSanitizesInfinityToZero() {
        let color = LUTColor(red: .infinity, green: -.infinity, blue: 0.25)
        #expect(color.red == 0)
        #expect(color.green == 0)
        #expect(color.blue == 0.25)
    }

    @Test
    func testLUTColorArithmeticSanitizesProducedNaN() {
        // 0 * Inf is NaN; the sanitizer must intercept it on construction.
        let zero = LUTColor.zeros()
        let infiniteScalar = Double.infinity
        let scaled = zero.multiplied(by: infiniteScalar)
        #expect(scaled.red == 0)
        #expect(scaled.green == 0)
        #expect(scaled.blue == 0)
    }

    @Test
    func testLerpAtZeroReturnsSelf() {
        let a = LUTColor.color(red: 0.1, green: 0.2, blue: 0.3)
        let b = LUTColor.color(red: 0.9, green: 0.7, blue: 0.5)
        let result = a.lerping(to: b, amount: 0)
        #expect(abs(result.red - a.red) < 1e-12)
        #expect(abs(result.green - a.green) < 1e-12)
        #expect(abs(result.blue - a.blue) < 1e-12)
    }

    @Test
    func testLerpAtOneReturnsTarget() {
        let a = LUTColor.color(red: 0.1, green: 0.2, blue: 0.3)
        let b = LUTColor.color(red: 0.9, green: 0.7, blue: 0.5)
        let result = a.lerping(to: b, amount: 1)
        #expect(abs(result.red - b.red) < 1e-12)
        #expect(abs(result.green - b.green) < 1e-12)
        #expect(abs(result.blue - b.blue) < 1e-12)
    }

    @Test
    func testFromIntegersWithZeroBitDepthReturnsZeros() {
        // Defensive path: bitDepth=0 would imply maxValue=0; the API guards it.
        let color = LUTColor.fromIntegers(bitDepth: 0, red: 100, green: 200, blue: 50)
        #expect(color == .zeros())
    }

    // MARK: - LUT/LUT1D minimum size

    @Test
    func testLUT1DSizeOneRoundTrips() {
        let lut = LUT1D(redCurve: [0.25],
                        greenCurve: [0.5],
                        blueCurve: [0.75],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        #expect(lut.size == 1)
        let color = lut.colorAt(index: 0)
        #expect(color.red == 0.25)
        #expect(color.green == 0.5)
        #expect(color.blue == 0.75)

        // Interpolated lookups must clamp to the only sample.
        let interp = lut.colorAtInterpolated(red: 0, green: 0, blue: 0)
        #expect(abs(interp.red - 0.25) < 1e-12)
        #expect(abs(interp.green - 0.5) < 1e-12)
        #expect(abs(interp.blue - 0.75) < 1e-12)
    }

    @Test
    func testLUT1DSizeOneToLUT3DDoesNotCrash() {
        let lut = LUT1D(redCurve: [0.4],
                        greenCurve: [0.4],
                        blueCurve: [0.4],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        let cube = lut.toLUT3D(size: 3)
        #expect(cube.size == 3)
        // All output cells should hold the only sample value.
        let center = cube.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(center.red - 0.4) < 1e-9)
    }

    @Test
    func testLUTSizeOneIdentity() {
        let lut = LUT.identity(size: 1, inputLowerBound: 0, inputUpperBound: 1)
        #expect(lut.size == 1)
        let color = lut.colorAt(r: 0, g: 0, b: 0)
        // identity at the only sample: input lower bound on every channel.
        #expect(color.red == 0)
        #expect(color.green == 0)
        #expect(color.blue == 0)
    }

    @Test
    func testLUT3DFalseColorSizeOneEvaluatesBlackBucket() {
        let lut = LUT3D.falseColor(size: 1)
        #expect(lut.size == 1)
        // The single sample is identity at (0,0,0), luminance 0 → purple bucket.
        let color = lut.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(color.red - 0.5) < 1e-9)
        #expect(color.green == 0)
        #expect(abs(color.blue - 0.5) < 1e-9)
    }

    // MARK: - LUT1D reversibility / monotonicity

    @Test
    func testIsReversibleStrictRejectsPlateau() {
        // Constant curve fails strict monotonicity but passes non-strict.
        let lut = LUT1D(redCurve: [0.5, 0.5, 0.5],
                        greenCurve: [0.5, 0.5, 0.5],
                        blueCurve: [0.5, 0.5, 0.5],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        #expect(lut.isReversible(strict: true) == false)
        #expect(lut.isReversible(strict: false) == true)
    }

    @Test
    func testIsReversibleRejectsNonMonotonicCurve() {
        let lut = LUT1D(redCurve: [0, 0.4, 0.2, 1.0],
                        greenCurve: [0, 0.5, 0.7, 1.0],
                        blueCurve: [0, 0.3, 0.6, 1.0],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        #expect(lut.isReversible(strict: false) == false)
    }

    @Test
    func testReversedReturnsNilForNonMonotonicCurve() {
        let lut = LUT1D(redCurve: [0, 0.6, 0.3, 1.0],
                        greenCurve: [0, 0.6, 0.3, 1.0],
                        blueCurve: [0, 0.6, 0.3, 1.0],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        let reversed = lut.reversed(strictness: false, autoAdjustInputBounds: false)
        #expect(reversed == nil)
    }

    @Test
    func testExtractingColorShiftReturnsNilForNonMonotonic3D() {
        // Build a LUT3D whose diagonal (toLUT1D) is non-monotonic.
        var lut = LUT3D.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        // Diagonal: (0,0,0), (0.5,0.5,0.5), (1,1,1) → make middle smaller than start.
        lut.setColor(LUTColor.color(red: 0.8, green: 0.8, blue: 0.8), r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 0.3, green: 0.3, blue: 0.3), r: 1, g: 1, b: 1)
        lut.setColor(LUTColor.color(red: 0.9, green: 0.9, blue: 0.9), r: 2, g: 2, b: 2)
        let shifted = lut.extractingColorShift(strictness: false)
        #expect(shifted == nil)
    }

    // MARK: - LUT.combined fast vs slow path

    @Test
    func testCombinedSameSizeIsIdempotentOnIdentity() {
        let a = LUT.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let b = LUT.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let combined = a.combined(with: b)
        #expect(combined.size == 5)
        for r in 0..<5 {
            for g in 0..<5 {
                for b2 in 0..<5 {
                    let actual = combined.colorAt(r: r, g: g, b: b2)
                    let expected = a.colorAt(r: r, g: g, b: b2)
                    #expect(abs(actual.red - expected.red) < 1e-9)
                    #expect(abs(actual.green - expected.green) < 1e-9)
                    #expect(abs(actual.blue - expected.blue) < 1e-9)
                }
            }
        }
    }

    @Test
    func testCombinedDifferentSizesProducesIdentityForIdentities() {
        let small = LUT.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let large = LUT.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let combined = small.combined(with: large)
        // combined() picks max(size). Identity ⊙ identity stays identity, but at
        // the larger resolution.
        #expect(combined.size == 5)
        for r in 0..<combined.size {
            for g in 0..<combined.size {
                for b in 0..<combined.size {
                    let actual = combined.colorAt(r: r, g: g, b: b)
                    let expected = combined.identityColorAt(r: Double(r),
                                                            g: Double(g),
                                                            b: Double(b))
                    #expect(abs(actual.red - expected.red) < 1e-6)
                    #expect(abs(actual.green - expected.green) < 1e-6)
                    #expect(abs(actual.blue - expected.blue) < 1e-6)
                }
            }
        }
    }

    // MARK: - LUT.changingStrength boundary values

    @Test
    func testChangingStrengthOneReturnsSelf() {
        let lut = LUT.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let result = lut.changingStrength(1.0)
        #expect(result.equals(lut, tolerance: 1e-12))
    }

    @Test
    func testChangingStrengthZeroProducesIdentity() {
        // Strength 0 lerps from identity towards LUT by 0% — i.e. pure identity.
        var lut = LUT.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        // Push the diagonal off-identity so the test would distinguish cases.
        lut.setColor(LUTColor.color(red: 0.9, green: 0.1, blue: 0.5), r: 1, g: 1, b: 1)
        let result = lut.changingStrength(0)
        let identity = LUT.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        #expect(result.equals(identity, tolerance: 1e-9))
    }

    // MARK: - LUT.inverted

    @Test
    func testInvertedFlipsIdentityAroundOne() {
        let lut = LUT.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let inverted = lut.inverted()
        let zero = inverted.colorAt(r: 0, g: 0, b: 0)
        let one = inverted.colorAt(r: 2, g: 2, b: 2)
        // identity(0)=0 → inverted = 1; identity(1)=1 → inverted = 0.
        #expect(abs(zero.red - 1) < 1e-9)
        #expect(abs(one.red - 0) < 1e-9)
    }
}
