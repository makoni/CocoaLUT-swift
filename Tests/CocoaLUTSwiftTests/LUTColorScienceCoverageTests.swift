import Testing
import simd
@testable import CocoaLUTSwift

// Smoke + round-trip coverage that iterates every predefined color space,
// transfer function, and white point so any new entry inherits these checks
// for free.
@Suite
struct LUTColorScienceCoverageTests {

    // MARK: - Color spaces

    @Test
    func testAllKnownColorSpacesProduceValidNPM() throws {
        let whitePoint = LUTColorSpaceWhitePoint.d65
        for space in LUTColorSpace.knownColorSpaces {
            let npm = try space.npm(using: whitePoint)
            // Every NPM column must contain finite numbers — sanity bound on the
            // entire matrix so a pathological constant doesn't slip through.
            for column in 0..<3 {
                for row in 0..<3 {
                    let value = npm[column][row]
                    #expect(value.isFinite, "Non-finite element in NPM for \(space.name) at (\(row),\(column))")
                }
            }
            // Round-trip with its inverse must approximate identity.
            let inverse = try space.npmInverse(using: whitePoint)
            let identity = npm * inverse
            for c in 0..<3 {
                for r in 0..<3 {
                    let expected: Double = (r == c) ? 1.0 : 0.0
                    #expect(abs(identity[c][r] - expected) < 1e-9,
                            "NPM × inverse not identity for \(space.name)")
                }
            }
        }
    }

    @Test
    func testTransformationMatrixIdentityForSameSpace() throws {
        for space in LUTColorSpace.knownColorSpaces {
            let matrix = try LUTColorSpace.transformationMatrix(from: space,
                                                                sourceWhitePoint: .d65,
                                                                to: space,
                                                                destinationWhitePoint: .d65,
                                                                useBradfordMatrix: false)
            for c in 0..<3 {
                for r in 0..<3 {
                    let expected: Double = (r == c) ? 1.0 : 0.0
                    #expect(abs(matrix[c][r] - expected) < 1e-9,
                            "Self-transform not identity for \(space.name)")
                }
            }
        }
    }

    @Test
    func testRec709ToP3RoundTripPreservesIdentity() throws {
        let identity = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let toP3 = try LUTColorSpace.convert(identity,
                                              from: .rec709,
                                              sourceWhitePoint: .d65,
                                              to: .dciP3,
                                              destinationWhitePoint: .d65,
                                              useBradfordMatrix: false)
        let back = try LUTColorSpace.convert(toP3,
                                              from: .dciP3,
                                              sourceWhitePoint: .d65,
                                              to: .rec709,
                                              destinationWhitePoint: .d65,
                                              useBradfordMatrix: false)
        // Round-trip must match the original identity within float precision.
        #expect(back.equals(identity, tolerance: 1e-6))
    }

    @Test
    func testBradfordD65ToD50RoundTrip() throws {
        let identity = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)
        let toD50 = try LUTColorSpace.convert(identity,
                                               from: .rec709,
                                               sourceWhitePoint: .d65,
                                               to: .rec709,
                                               destinationWhitePoint: .d50,
                                               useBradfordMatrix: true)
        let back = try LUTColorSpace.convert(toD50,
                                              from: .rec709,
                                              sourceWhitePoint: .d50,
                                              to: .rec709,
                                              destinationWhitePoint: .d65,
                                              useBradfordMatrix: true)
        #expect(back.equals(identity, tolerance: 1e-6))
    }

    // MARK: - White points

    @Test
    func testAllKnownWhitePointsHaveValidTristimulus() {
        for whitePoint in LUTColorSpaceWhitePoint.knownWhitePoints {
            let xyz = whitePoint.tristimulusValues
            #expect(xyz.x.isFinite)
            #expect(xyz.y.isFinite)
            #expect(xyz.z.isFinite)
            // Y is normalised to 1.0 by construction.
            #expect(abs(xyz.y - 1.0) < 1e-9, "Y != 1 for \(whitePoint.name)")
            // Sum of components must be positive (no zero/negative chromaticities).
            #expect(xyz.x + xyz.y + xyz.z > 0)
        }
    }

    @Test
    func testRobertsonClampsBelowMinimumKelvin() {
        // Below 1667K the formula is undefined → the API returns nil.
        #expect(LUTColorSpaceWhitePoint.fromColorTemperature(1666) == nil)
        #expect(LUTColorSpaceWhitePoint.fromColorTemperature(0) == nil)
    }

    @Test
    func testRobertsonClampsAboveMaximumKelvin() {
        #expect(LUTColorSpaceWhitePoint.fromColorTemperature(25_001) == nil)
        #expect(LUTColorSpaceWhitePoint.fromColorTemperature(50_000) == nil)
    }

    @Test
    func testRobertsonAt6504KApproximatesD65() {
        // 6504K is the canonical D65 correlated colour temperature.
        let approxD65 = LUTColorSpaceWhitePoint.fromColorTemperature(6504)
        #expect(approxD65 != nil)
        if let approxD65 {
            let d65 = LUTColorSpaceWhitePoint.d65
            #expect(abs(approxD65.whiteChromaticityX - d65.whiteChromaticityX) < 0.01)
            #expect(abs(approxD65.whiteChromaticityY - d65.whiteChromaticityY) < 0.01)
        }
    }

    @Test
    func testKnownColorTemperatureWhitePointsContainsExpectedKelvins() {
        let presets = LUTColorSpaceWhitePoint.knownColorTemperatureWhitePoints
        #expect(presets.count == 4)
        let names = presets.map(\.name)
        #expect(names.contains { $0.contains("2900K") })
        #expect(names.contains { $0.contains("3200K") })
        #expect(names.contains { $0.contains("4400K") })
        #expect(names.contains { $0.contains("5600K") })
    }

    // MARK: - Transfer functions

    @Test
    func testAllKnownTransferFunctionsRoundTripMidGrey() {
        // Log-based TFs have wider numeric drift than gamma; 1e-4 is loose
        // enough for every member of the registry yet still catches real bugs.
        for tf in LUTColorTransferFunction.knownColorTransferFunctions() {
            let midGrey = LUTColor.uniform(0.18)
            let toLinear = tf.transformedToLinear(from: midGrey)
            let back = tf.linearToTransformed(from: toLinear)
            #expect(abs(back.red - midGrey.red) < 1e-4, "\(tf.name) round-trip drift @0.18 red")
            #expect(abs(back.green - midGrey.green) < 1e-4, "\(tf.name) round-trip drift @0.18 green")
            #expect(abs(back.blue - midGrey.blue) < 1e-4, "\(tf.name) round-trip drift @0.18 blue")
        }
    }

    @Test
    func testAllKnownTransferFunctionsRoundTripUnitInterval() {
        // Sample three points well inside the legal unit interval. Skipping the
        // exact 0/1 endpoints because some log TFs use cached lookup tables
        // whose extrapolation behaviour is undefined at the boundary.
        for tf in LUTColorTransferFunction.knownColorTransferFunctions() {
            for sample in [0.05, 0.5, 0.95] {
                let color = LUTColor.uniform(sample)
                let linear = tf.transformedToLinear(from: color)
                let back = tf.linearToTransformed(from: linear)
                #expect(abs(back.red - color.red) < 1e-4, "\(tf.name) round-trip drift @\(sample)")
            }
        }
    }

    @Test
    func testGammaOneIsIdentity() {
        let tf = LUTColorTransferFunction.gammaTransferFunction(gamma: 1.0)
        for v in stride(from: 0.0, through: 1.0, by: 0.1) {
            let color = LUTColor.uniform(v)
            let linear = tf.transformedToLinear(from: color)
            #expect(abs(linear.red - v) < 1e-12)
        }
    }

    @Test
    func testSRGBLinearRegionRoundTripsExactly() {
        // sRGB has a piecewise linear segment for x < 0.04045. Earlier renderers
        // sometimes implemented only the gamma branch and broke shadow detail.
        guard let sRGB = LUTColorTransferFunction.knownColorTransferFunctions()
                .first(where: { $0.name == "sRGB" }) else {
            Issue.record("sRGB transfer function missing from registry")
            return
        }
        for sample in [0.001, 0.01, 0.03, 0.04] {
            let color = LUTColor.uniform(sample)
            let linear = sRGB.transformedToLinear(from: color)
            let back = sRGB.linearToTransformed(from: linear)
            #expect(abs(back.red - sample) < 1e-9, "sRGB linear-region drift @\(sample)")
        }
    }

    @Test
    func testTransferFunctionCompatibility() {
        let known = LUTColorTransferFunction.knownColorTransferFunctions()
        guard let linear = known.first(where: { $0.name == "Linear" }),
              let sRGB = known.first(where: { $0.name == "sRGB" }),
              let gamma22 = known.first(where: { $0.name == "Gamma 2.2" }) else {
            Issue.record("Expected known transfer functions are missing from registry")
            return
        }

        // Same type → compatible.
        #expect(sRGB.isCompatible(with: gamma22))
        // .any matches everything.
        #expect(linear.isCompatible(with: sRGB))
        #expect(linear.isCompatible(with: gamma22))
        // Self-compatibility is reflexive.
        for tf in known {
            #expect(tf.isCompatible(with: tf))
        }
    }

    @Test
    func testTransformedLUT3DRoundTripsThroughSRGB() {
        let identity = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)
        let known = LUTColorTransferFunction.knownColorTransferFunctions()
        guard let sRGB = known.first(where: { $0.name == "sRGB" }),
              let linear = known.first(where: { $0.name == "Linear" }) else {
            Issue.record("sRGB or Linear missing from registry")
            return
        }
        let toLinear = LUTColorTransferFunction.transformedLUT(from: identity,
                                                                sourceTransferFunction: sRGB,
                                                                destinationTransferFunction: linear)
        let back = LUTColorTransferFunction.transformedLUT(from: toLinear,
                                                            sourceTransferFunction: linear,
                                                            destinationTransferFunction: sRGB)
        #expect(back.equals(identity, tolerance: 1e-5))
    }
}
