import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTColorTransferFunctionTests {
    @Test
    func testGammaTransferFunctionRoundTrip() {
        let gamma = LUTColorTransferFunction.gammaTransferFunction(gamma: 2.2)
        let source = LUTColor.color(red: 0.5, green: 0.25, blue: 0.75)
        let linear = gamma.transformedToLinear(from: source)
        let roundTrip = gamma.linearToTransformed(from: linear)

        XCTAssertEqual(roundTrip.red, source.red, accuracy: 1e-9)
        XCTAssertEqual(roundTrip.green, source.green, accuracy: 1e-9)
        XCTAssertEqual(roundTrip.blue, source.blue, accuracy: 1e-9)
    }

    @Test
    func testCompatibilityRelation() {
        let gamma = LUTColorTransferFunction.gammaTransferFunction(gamma: 2.4)
        let linear = LUTColorTransferFunction.linearTransferFunction()
        XCTAssertTrue(linear.isCompatible(with: gamma))
        XCTAssertTrue(gamma.isCompatible(with: linear))
    }

    @Test
    func testTransformedLUT1DRoundTrip() {
        var lut = LUT1D.uniformCurve(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(.color(red: 0.0, green: 0.1, blue: 0.2), index: 0)
        lut.setColor(.color(red: 0.25, green: 0.35, blue: 0.45), index: 1)
        lut.setColor(.color(red: 0.5, green: 0.6, blue: 0.7), index: 2)
        lut.setColor(.color(red: 0.9, green: 1.0, blue: 0.8), index: 3)

        let sourceTF = LUTColorTransferFunction.gammaTransferFunction(gamma: 2.2)
        let destinationTF = LUTColorTransferFunction.linearTransferFunction()

        let transformed = LUTColorTransferFunction.transformedLUT(from: lut,
                                                                  sourceTransferFunction: sourceTF,
                                                                  destinationTransferFunction: destinationTF)
        let roundTrip = LUTColorTransferFunction.transformedLUT(from: transformed,
                                                                sourceTransferFunction: destinationTF,
                                                                destinationTransferFunction: sourceTF)

        for index in 0..<lut.size {
            let expected = lut.colorAt(index: index)
            let actual = roundTrip.colorAt(index: index)
            XCTAssertEqual(actual.red, expected.red, accuracy: 1e-9)
            XCTAssertEqual(actual.green, expected.green, accuracy: 1e-9)
            XCTAssertEqual(actual.blue, expected.blue, accuracy: 1e-9)
        }
    }
}
