import XCTest
@testable import CocoaLUT_swift

final class LUT1DTests: XCTestCase {
    func testInitializationStoresCurves() {
    let red = stride(from: 0.0, through: 1.0, by: 0.25).map { $0 }
    let green = red.map { pow($0, 2) }
    let blue = Array(red.reversed())
        let lut = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        XCTAssertEqual(lut.size, red.count)
        XCTAssertEqual(lut.valueAtR(2), red[2])
        XCTAssertEqual(lut.valueAtG(3), green[3])
        XCTAssertEqual(lut.valueAtB(1), blue[1])
        XCTAssertEqual(lut.inputLowerBound, 0.0)
        XCTAssertEqual(lut.inputUpperBound, 1.0)
    }

    func testColorMappingUsesInterpolationAndClamping() {
        let red: [Double] = [0.0, 0.2, 0.6, 0.8, 1.0]
        let green: [Double] = [0.0, 0.1, 0.4, 0.7, 1.0]
        let blue: [Double] = [0.0, 0.3, 0.5, 0.9, 1.1]
        let lut = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        let input = LUTColor.color(red: 0.42, green: -0.25, blue: 1.3)
        let output = lut.color(at: input)

        let expectedRed = lerp(red[1], red[2], t: 0.42 * 4.0 - 1.0)
        XCTAssertEqual(output.red, expectedRed, accuracy: 1e-9)
        XCTAssertEqual(output.green, green.first!, accuracy: 1e-9)
        XCTAssertEqual(output.blue, blue.last!, accuracy: 1e-9)
    }

    func testResizingInterpolatesCurves() {
        let red: [Double] = [0.0, 0.5, 1.0]
        let green: [Double] = [0.0, 0.25, 0.5]
        let blue: [Double] = [0.0, 0.75, 1.5]
        let lut = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        let resized = lut.resized(to: 5)
        XCTAssertEqual(resized.size, 5)
        XCTAssertEqual(resized.valueAtR(2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(resized.valueAtG(3), 0.375, accuracy: 1e-9)
        XCTAssertEqual(resized.valueAtB(4), 1.5, accuracy: 1e-9)
    }

    func testToLUT3DProducesExpectedCube() {
        let red: [Double] = [0.0, 0.5, 1.0]
        let green: [Double] = [0.1, 0.6, 1.1]
        let blue: [Double] = [0.2, 0.7, 1.2]
        let lut1D = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        let lut3D = lut1D.toLUT3D(size: 3)
        XCTAssertEqual(lut3D.size, 3)
        let color = lut3D.colorAt(r: 1, g: 2, b: 0)
        XCTAssertEqual(color.red, red[1], accuracy: 1e-9)
        XCTAssertEqual(color.green, green[2], accuracy: 1e-9)
        XCTAssertEqual(color.blue, blue[0], accuracy: 1e-9)
    }

    func testIsReversibleDetectsMonotonicCurves() {
        let size = 8
        let curve = monotonicCurve(size: size, exponent: 1.0)
        let lut = LUT1D(redCurve: curve,
                        greenCurve: curve,
                        blueCurve: curve,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        XCTAssertTrue(lut.isReversible(strict: true))

        var nonMonotonicCurve = curve
        if nonMonotonicCurve.count > 2 {
            nonMonotonicCurve[2] = nonMonotonicCurve[1] - 0.05
        }

        let nonMonotonic = LUT1D(redCurve: nonMonotonicCurve,
                                 greenCurve: nonMonotonicCurve,
                                 blueCurve: nonMonotonicCurve,
                                 inputLowerBound: 0,
                                 inputUpperBound: 1)

        XCTAssertFalse(nonMonotonic.isReversible(strict: true))
    }

    func testReversedCurveRestoresInput() {
        let size = 64
        let curve = monotonicCurve(size: size, exponent: 2.0)
        let lut = LUT1D(redCurve: curve,
                        greenCurve: curve,
                        blueCurve: curve,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let reversed = lut.reversed(strictness: true, autoAdjustInputBounds: true)
        XCTAssertNotNil(reversed)

        let testValue = 0.42
        let forward = lut.color(at: LUTColor.color(red: testValue, green: testValue, blue: testValue))
        let recovered = reversed?.color(at: forward)

        XCTAssertEqual(recovered?.red ?? 0, testValue, accuracy: 1e-3)
        XCTAssertEqual(recovered?.green ?? 0, testValue, accuracy: 1e-3)
        XCTAssertEqual(recovered?.blue ?? 0, testValue, accuracy: 1e-3)
    }

    func testSwizzledCopiesRedChannel() {
        let size = 6
        let red = monotonicCurve(size: size, exponent: 1.0)
        let green = monotonicCurve(size: size, exponent: 1.3)
        let blue = monotonicCurve(size: size, exponent: 0.8)

        let lut = LUT1D(redCurve: red,
                        greenCurve: green,
                        blueCurve: blue,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let swizzled = lut.swizzled(using: .redCopiedToRGB)

        for index in 0..<size {
            let redValue = lut.valueAtR(index)
            XCTAssertEqual(swizzled.valueAtR(index), redValue, accuracy: 1e-9)
            XCTAssertEqual(swizzled.valueAtG(index), redValue, accuracy: 1e-9)
            XCTAssertEqual(swizzled.valueAtB(index), redValue, accuracy: 1e-9)
        }
    }
}

final class LUT3DTests: XCTestCase {
    func testIdentityMatchesUnderlyingLUT() {
        let identity = LUT3D.identity(size: 4, inputLowerBound: -1.0, inputUpperBound: 2.0)
        for r in 0..<identity.size {
            for g in 0..<identity.size {
                for b in 0..<identity.size {
                    let expected = identity.asLUT().identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                    let actual = identity.colorAt(r: r, g: g, b: b)
                    XCTAssertEqual(actual.red, expected.red, accuracy: 1e-9)
                    XCTAssertEqual(actual.green, expected.green, accuracy: 1e-9)
                    XCTAssertEqual(actual.blue, expected.blue, accuracy: 1e-9)
                }
            }
        }
    }
}

private func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
    a + (b - a) * t
}

private func monotonicCurve(size: Int, exponent: Double) -> [Double] {
    guard size > 1 else { return [0] }
    return (0..<size).map { index in
        pow(Double(index) / Double(size - 1), exponent)
    }
}
