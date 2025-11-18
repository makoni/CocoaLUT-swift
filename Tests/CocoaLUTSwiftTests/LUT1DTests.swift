import Testing
@testable import CocoaLUTSwift

@Suite
struct LUT1DTests {
    @Test
    func testInitializationStoresCurves() {
        let red = stride(from: 0.0, through: 1.0, by: 0.25).map { $0 }
        let green = red.map { pow($0, 2) }
        let blue = Array(red.reversed())
        let lut = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        #expect(lut.size == red.count)
        #expect(lut.valueAtR(2) == red[2])
        #expect(lut.valueAtG(3) == green[3])
        #expect(lut.valueAtB(1) == blue[1])
        #expect(lut.inputLowerBound == 0.0)
        #expect(lut.inputUpperBound == 1.0)
    }

    @Test
    func testColorMappingUsesInterpolationAndClamping() {
        let red: [Double] = [0.0, 0.2, 0.6, 0.8, 1.0]
        let green: [Double] = [0.0, 0.1, 0.4, 0.7, 1.0]
        let blue: [Double] = [0.0, 0.3, 0.5, 0.9, 1.1]
        let lut = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        let input = LUTColor.color(red: 0.42, green: -0.25, blue: 1.3)
        let output = lut.color(at: input)

        let expectedRed = lerp(red[1], red[2], t: 0.42 * 4.0 - 1.0)
        #expect(abs(output.red - expectedRed) < 1e-9)
        #expect(abs(output.green - green.first!) < 1e-9)
        #expect(abs(output.blue - blue.last!) < 1e-9)
    }

    @Test
    func testResizingInterpolatesCurves() {
        let red: [Double] = [0.0, 0.5, 1.0]
        let green: [Double] = [0.0, 0.25, 0.5]
        let blue: [Double] = [0.0, 0.75, 1.5]
        let lut = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        let resized = lut.resized(to: 5)
        #expect(resized.size == 5)
        #expect(abs(resized.valueAtR(2) - 0.5) < 1e-9)
        #expect(abs(resized.valueAtG(3) - 0.375) < 1e-9)
        #expect(abs(resized.valueAtB(4) - 1.5) < 1e-9)
    }

    @Test
    func testToLUT3DProducesExpectedCube() {
        let red: [Double] = [0.0, 0.5, 1.0]
        let green: [Double] = [0.1, 0.6, 1.1]
        let blue: [Double] = [0.2, 0.7, 1.2]
        let lut1D = LUT1D(redCurve: red, greenCurve: green, blueCurve: blue, inputLowerBound: 0.0, inputUpperBound: 1.0)

        let lut3D = lut1D.toLUT3D(size: 3)
        #expect(lut3D.size == 3)
        let color = lut3D.colorAt(r: 1, g: 2, b: 0)
        #expect(abs(color.red - red[1]) < 1e-9)
        #expect(abs(color.green - green[2]) < 1e-9)
        #expect(abs(color.blue - blue[0]) < 1e-9)
    }

    @Test
    func testIsReversibleDetectsMonotonicCurves() {
        let size = 8
        let curve = monotonicCurve(size: size, exponent: 1.0)
        let lut = LUT1D(redCurve: curve,
                        greenCurve: curve,
                        blueCurve: curve,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        #expect(lut.isReversible(strict: true))

        var nonMonotonicCurve = curve
        if nonMonotonicCurve.count > 2 {
            nonMonotonicCurve[2] = nonMonotonicCurve[1] - 0.05
        }

        let nonMonotonic = LUT1D(redCurve: nonMonotonicCurve,
                                 greenCurve: nonMonotonicCurve,
                                 blueCurve: nonMonotonicCurve,
                                 inputLowerBound: 0,
                                 inputUpperBound: 1)

        #expect(!nonMonotonic.isReversible(strict: true))
    }

    @Test
    func testReversedCurveRestoresInput() {
        let size = 64
        let curve = monotonicCurve(size: size, exponent: 2.0)
        let lut = LUT1D(redCurve: curve,
                        greenCurve: curve,
                        blueCurve: curve,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let reversed = lut.reversed(strictness: true, autoAdjustInputBounds: true)
        #expect(reversed != nil)

        let testValue = 0.42
        let forward = lut.color(at: LUTColor.color(red: testValue, green: testValue, blue: testValue))
        let recovered = reversed?.color(at: forward)

        #expect(abs((recovered?.red ?? 0) - testValue) < 1e-3)
        #expect(abs((recovered?.green ?? 0) - testValue) < 1e-3)
        #expect(abs((recovered?.blue ?? 0) - testValue) < 1e-3)
    }

    @Test
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
            #expect(abs(swizzled.valueAtR(index) - redValue) < 1e-9)
            #expect(abs(swizzled.valueAtG(index) - redValue) < 1e-9)
            #expect(abs(swizzled.valueAtB(index) - redValue) < 1e-9)
        }
    }
}

@Suite
struct LUT3DTests {
    @Test
    func testIdentityMatchesUnderlyingLUT() {
        let identity = LUT3D.identity(size: 4, inputLowerBound: -1.0, inputUpperBound: 2.0)
        for r in 0..<identity.size {
            for g in 0..<identity.size {
                for b in 0..<identity.size {
                    let expected = identity.asLUT().identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                    let actual = identity.colorAt(r: r, g: g, b: b)
                    #expect(abs(actual.red - expected.red) < 1e-9)
                    #expect(abs(actual.green - expected.green) < 1e-9)
                    #expect(abs(actual.blue - expected.blue) < 1e-9)
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
