import Testing
import simd
@testable import CocoaLUTSwift

@Suite
struct LUTColorSpaceTests {
    @Test
    func testTransformationMatrixWithIdenticalColorSpacesIsIdentity() throws {
        let matrix = try LUTColorSpace.transformationMatrix(from: .rec709,
                                                             sourceWhitePoint: .d65,
                                                             to: .rec709,
                                                             destinationWhitePoint: .d65,
                                                             useBradfordMatrix: false)
        let identity = simd_double3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)])
        #expect(matrix.isApproximatelyEqual(to: identity, tolerance: 1e-9))
    }

    @Test
    func testConvertPreservesIdentityLUTBetweenIdenticalColorSpaces() throws {
        var lut = LUT3D.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.2, green: 0.4, blue: 0.6), r: 0, g: 0, b: 0)

        let transformed = try LUTColorSpace.convert(lut,
                                                    from: .rec709,
                                                    sourceWhitePoint: .d65,
                                                    to: .rec709,
                                                    destinationWhitePoint: .d65,
                                                    useBradfordMatrix: false)

        #expect(transformed.equals(lut, tolerance: 1e-9))
    }

    @Test
    func testConvertAppliesFootLambertCompensation() throws {
        let source = LUTColorSpace.forcedNPM(simd_double3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)]),
                                             forwardFootlambertCompensation: 0.5,
                                             name: "Source")
        let destination = LUTColorSpace.forcedNPM(simd_double3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)]),
                                                  forwardFootlambertCompensation: 2.0,
                                                  name: "Destination")

        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.25, green: 0.25, blue: 0.25), r: 0, g: 0, b: 0)

        let converted = try LUTColorSpace.convert(lut,
                                                  from: source,
                                                  sourceWhitePoint: .d65,
                                                  to: destination,
                                                  destinationWhitePoint: .d65,
                                                  useBradfordMatrix: false)

        let convertedColor = converted.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(convertedColor.red - 1.0) < 1e-9)
        #expect(abs(convertedColor.green - 1.0) < 1e-9)
        #expect(abs(convertedColor.blue - 1.0) < 1e-9)
    }

    @Test
    func testConvertThrowsWhenRequestingBradfordWithForcedNPM() throws {
        let forced = LUTColorSpace.forcedNPM(simd_double3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)]),
                                             name: "Forced")
        let other = LUTColorSpace.rec709

        #expect {
            try LUTColorSpace.convert(.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1),
                                       from: forced,
                                       sourceWhitePoint: .d65,
                                       to: other,
                                       destinationWhitePoint: .d65,
                                       useBradfordMatrix: true)
        } throws: { error in
            error as? LUTColorSpace.Error == .bradfordMatrixUnsupportedForForcedNPM
        }
    }

    @Test
    func testConvertColorTemperatureMatchesManualTransform() throws {
        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.3, green: 0.5, blue: 0.7), r: 1, g: 1, b: 1)

        guard let sourceTemperature = LUTColorSpaceWhitePoint.fromColorTemperature(5600),
              let destinationTemperature = LUTColorSpaceWhitePoint.fromColorTemperature(3200) else {
            Issue.record("Expected valid color temperatures")
            return
        }

        let transfer = LUTColorTransferFunction.gammaTransferFunction(gamma: 2.2)
        let linear = LUTColorTransferFunction.linearTransferFunction()

        let manualLinearized = LUTColorTransferFunction.transformedLUT(from: lut,
                                                                       sourceTransferFunction: transfer,
                                                                       destinationTransferFunction: linear)
        let manualConverted = try LUTColorSpace.convert(manualLinearized,
                                                        from: .rec709,
                                                        sourceWhitePoint: sourceTemperature,
                                                        to: .rec709,
                                                        destinationWhitePoint: destinationTemperature,
                                                        useBradfordMatrix: false)
        let manualResult = LUTColorTransferFunction.transformedLUT(from: manualConverted,
                                                                    sourceTransferFunction: linear,
                                                                    destinationTransferFunction: transfer)

        let helperResult = try LUTColorSpace.convertColorTemperature(lut,
                                                                      sourceColorSpace: .rec709,
                                                                      sourceTransferFunction: transfer,
                                                                      sourceColorTemperature: sourceTemperature,
                                                                      destinationColorTemperature: destinationTemperature)

        #expect(helperResult.equals(manualResult, tolerance: 1e-9))
    }
}

private extension simd_double3x3 {
    func isApproximatelyEqual(to other: simd_double3x3, tolerance: Double) -> Bool {
        for row in 0..<3 {
            for column in 0..<3 {
                if abs(self[row][column] - other[row][column]) > tolerance {
                    return false
                }
            }
        }
        return true
    }
}
