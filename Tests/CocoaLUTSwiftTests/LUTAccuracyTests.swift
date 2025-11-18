import simd
import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTAccuracyTests {
    @Test
    func testResizeAccuracy1DIdentity() {
        let identity = LUT1D.uniformCurve(size: 1024,
                                          inputLowerBound: 0,
                                          inputUpperBound: 1)

        let resized = identity
            .resized(to: 2048)
            .resized(to: 4096)
            .resized(to: 1024)

        assertEqual(identity, resized, accuracy: 1e-9)
    }

    @Test
    func testResizeAccuracy3DIdentity() {
        let identity = LUT3D.identity(size: 33,
                                      inputLowerBound: 0,
                                      inputUpperBound: 1)

        let resized = identity
            .resized(to: 64)
            .resized(to: 35)
            .resized(to: 33)

        #expect(resized.equals(identity), "3D identity resize should remain lossless")
    }

    @Test
    func testAlexaCubeResizeMatchesReference() throws {
        let lut33 = try loadAlexaCube(size: 33)
        let lut65Reference = try loadAlexaCube(size: 65)

        let upsampled = lut33.resized(to: 65)
        let metrics = upsampled.comparisonMetrics(against: lut65Reference)

        // With tetrahedral interpolation, we expect to match the CocoaLUT reference tolerances.
        #expect(metrics.sMAPE.red <= 0.010395)
        #expect(metrics.sMAPE.green <= 0.010160)
        #expect(metrics.sMAPE.blue <= 0.007201)

        #expect(metrics.maxAbsoluteError.red <= 0.132559)
        #expect(metrics.maxAbsoluteError.green <= 0.114145)
        #expect(metrics.maxAbsoluteError.blue <= 0.078125)

        #expect(metrics.averageAbsoluteError.red <= 0.001069)
        #expect(metrics.averageAbsoluteError.green <= 0.000813)
        #expect(metrics.averageAbsoluteError.blue <= 0.000516)

        let downsampled = lut65Reference.resized(to: 33)
        #expect(downsampled.equals(lut33), "Downsampled LUT should match original 33^3 data")
    }

    @Test
    func testReversingIdentityLUTIsLossless() throws {
        let identity = LUT1D.uniformCurve(size: 1024,
                                          inputLowerBound: 0,
                                          inputUpperBound: 1)

        let reversed = try #require(identity.reversed(strictness: true,
                                                        autoAdjustInputBounds: false))
        assertEqual(identity, reversed, accuracy: 1e-9)
    }

    @Test
    func testReversingGammaLUTProducesStableInverse() throws {
        let identity = LUT1D.uniformCurve(size: 1024,
                                          inputLowerBound: 0,
                                          inputUpperBound: 1)
        let linear = LUTColorTransferFunction.linearTransferFunction()
        let gamma26 = LUTColorTransferFunction.gammaTransferFunction(gamma: 2.6)

        let gammaLUT = LUTColorTransferFunction.transformedLUT(from: identity,
                                                               sourceTransferFunction: linear,
                                                               destinationTransferFunction: gamma26)

        let inverse = try #require(gammaLUT.reversed(strictness: true,
                                                       autoAdjustInputBounds: false))
        let doubleInverse = try #require(inverse.reversed(strictness: true,
                                                            autoAdjustInputBounds: false))

        assertEqual(gammaLUT, doubleInverse, accuracy: 2e-4)

        let sampleCount = gammaLUT.size
        for index in 0..<sampleCount {
            let input = sampleCount == 1 ? 0 : Double(index) / Double(sampleCount - 1)
            let source = LUTColor.uniform(input)
            let encoded = gammaLUT.color(at: source)
            let restored = inverse.color(at: encoded)

            #expect(abs(restored.red - input) < 1e-4)
            #expect(abs(restored.green - input) < 1e-4)
            #expect(abs(restored.blue - input) < 1e-4)
        }
    }
}

// MARK: - Helpers

private extension LUTAccuracyTests {
    func assertEqual(_ lhs: LUT1D,
                     _ rhs: LUT1D,
                     accuracy: Double,
                     sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(lhs.size == rhs.size, sourceLocation: sourceLocation)
        #expect(abs(lhs.inputLowerBound - rhs.inputLowerBound) < accuracy, sourceLocation: sourceLocation)
        #expect(abs(lhs.inputUpperBound - rhs.inputUpperBound) < accuracy, sourceLocation: sourceLocation)

        for index in 0..<lhs.size {
            #expect(abs(lhs.valueAtR(index) - rhs.valueAtR(index)) < accuracy, sourceLocation: sourceLocation)
            #expect(abs(lhs.valueAtG(index) - rhs.valueAtG(index)) < accuracy, sourceLocation: sourceLocation)
            #expect(abs(lhs.valueAtB(index) - rhs.valueAtB(index)) < accuracy, sourceLocation: sourceLocation)
        }
    }

    func loadAlexaCube(size: Int) throws -> LUT3D {
        let resourceName = "AlexaV3_K1S1_LogC2Video_Rec709_EE_\(size)"
        let url = try #require(Bundle.module.url(
            forResource: resourceName,
            withExtension: "cube",
            subdirectory: "Test LUTs"
        ), "Missing cube resource: \(resourceName)")

        let result = try LUTCubeFormatter.read(url: url)
        guard case let .lut3D(lut) = result else {
            Issue.record("Expected 3D LUT in \(resourceName).cube")
            throw FixtureError.invalidResource
        }
        return lut
    }
}

private extension LUT3D {
    struct ComparisonMetrics {
        let sMAPE: LUTColor
        let maxAbsoluteError: LUTColor
        let averageAbsoluteError: LUTColor
    }

    func comparisonMetrics(against other: LUT3D) -> ComparisonMetrics {
        precondition(size == other.size, "LUT sizes must match")

        var smapeTotal = SIMD3<Double>(repeating: 0)
        var absSum = SIMD3<Double>(repeating: 0)
        var maxAbs = SIMD3<Double>(repeating: 0)
        let totalSamples = Double(size * size * size)

        loop { r, g, b in
            let reference = colorAt(r: r, g: g, b: b)
            let candidate = other.colorAt(r: r, g: g, b: b)

            let diff = SIMD3(
                abs(reference.red - candidate.red),
                abs(reference.green - candidate.green),
                abs(reference.blue - candidate.blue)
            )

            absSum += diff
            maxAbs = simd.max(maxAbs, diff)

            smapeTotal += SIMD3(
                symmetricalPercentage(reference.red, candidate.red),
                symmetricalPercentage(reference.green, candidate.green),
                symmetricalPercentage(reference.blue, candidate.blue)
            )
        }

        let smape = smapeTotal / totalSamples
        let average = absSum / totalSamples

        return ComparisonMetrics(
            sMAPE: LUTColor.color(red: smape.x, green: smape.y, blue: smape.z),
            maxAbsoluteError: LUTColor.color(red: maxAbs.x, green: maxAbs.y, blue: maxAbs.z),
            averageAbsoluteError: LUTColor.color(red: average.x, green: average.y, blue: average.z)
        )
    }
}

private func symmetricalPercentage(_ lhs: Double, _ rhs: Double) -> Double {
    let denominator = abs(lhs) + abs(rhs)
    guard denominator > 0 else { return 0 }
    return abs(lhs - rhs) / denominator
}

private enum FixtureError: Error {
    case invalidResource
}
