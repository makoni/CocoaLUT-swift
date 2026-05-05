import Foundation
import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
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

@Suite(.serialized)
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

    @Test
    func testFalseColorLUTPaintsLuminanceBuckets() {
        // size=101 makes step = 0.01, so each integer index i maps to luminance i/100.
        let size = 101
        let lut = LUT3D.falseColor(size: size)
        let purple = LUTColor(red: 0.5, green: 0, blue: 0.5)
        let blue = LUTColor(red: 0, green: 0, blue: 1)
        let green = LUTColor(red: 0, green: 1, blue: 0)
        let pink = LUTColor(red: 1, green: 0.753, blue: 0.796)
        let yellow = LUTColor(red: 1, green: 1, blue: 0)

        // index 0 → lum 0 ≤ 0.025 → purple
        let black = lut.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(black.red - purple.red) < 1e-9)
        #expect(abs(black.green - purple.green) < 1e-9)
        #expect(abs(black.blue - purple.blue) < 1e-9)

        // index 3 → lum 0.03 ∈ (0.025, 0.04] → blue
        let blueBucket = lut.colorAt(r: 3, g: 3, b: 3)
        #expect(abs(blueBucket.red - blue.red) < 1e-9)
        #expect(abs(blueBucket.green - blue.green) < 1e-9)
        #expect(abs(blueBucket.blue - blue.blue) < 1e-9)

        // index 40 → lum 0.40 ∈ [0.38, 0.42] → green
        let greenBucket = lut.colorAt(r: 40, g: 40, b: 40)
        #expect(abs(greenBucket.red - green.red) < 1e-9)
        #expect(abs(greenBucket.green - green.green) < 1e-9)
        #expect(abs(greenBucket.blue - green.blue) < 1e-9)

        // index 54 → lum 0.54 ∈ [0.52, 0.56] → pink
        let pinkBucket = lut.colorAt(r: 54, g: 54, b: 54)
        #expect(abs(pinkBucket.red - pink.red) < 1e-9)
        #expect(abs(pinkBucket.green - pink.green) < 1e-9)
        #expect(abs(pinkBucket.blue - pink.blue) < 1e-9)

        // index 98 → lum 0.98 ∈ [0.97, 0.99] → yellow
        let yellowBucket = lut.colorAt(r: 98, g: 98, b: 98)
        #expect(abs(yellowBucket.red - yellow.red) < 1e-9)
        #expect(abs(yellowBucket.green - yellow.green) < 1e-9)
        #expect(abs(yellowBucket.blue - yellow.blue) < 1e-9)

        // Grey passthrough for an out-of-bucket luminance (index 20 → 0.20).
        let passthrough = lut.colorAt(r: 20, g: 20, b: 20)
        #expect(passthrough.red == passthrough.green)
        #expect(passthrough.green == passthrough.blue)
    }

    @Test
    func testApplyingFalseColorPreservesSize() {
        let identity = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let result = identity.applyingFalseColor()
        #expect(result.size == identity.size)
        #expect(result.inputLowerBound == identity.inputLowerBound)
        #expect(result.inputUpperBound == identity.inputUpperBound)
    }

    @Test
    func testApplyingFalseColorOnIdentityMatchesFalseColorLUT() {
        let identity = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let result = identity.applyingFalseColor()
        let reference = LUT3D.falseColor(size: 17)
        #expect(result.equals(reference, tolerance: 1e-6))
    }

    @Test
    func testApplyingFalseColorPropagatesMetadata() {
        var identity = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)
        identity.title = "Source"
        identity.descriptionText = "Description"
        let result = identity.applyingFalseColor()
        #expect(result.title == "Source")
        #expect(result.descriptionText == "Description")
    }

    @Test
    func testExtractingContrastOnlyRoundTripsIdentity() {
        let identity = LUT3D.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let result = identity.extractingContrastOnly()
        #expect(result.equals(identity, tolerance: 1e-9))
    }

    @Test
    func testConvertingToMonoAverageRGB() {
        let size = 3
        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<size { for g in 0..<size { for b in 0..<size {
            lut.setColor(LUTColor.color(red: 0.6, green: 0.3, blue: 0.0), r: r, g: g, b: b)
        }}}
        let mono = lut.convertingToMono(method: .averageRGB)
        let expected = (0.6 + 0.3 + 0.0) / 3.0
        let sample = mono.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(sample.red - expected) < 1e-9)
        #expect(sample.red == sample.green)
        #expect(sample.green == sample.blue)
    }

    @Test
    func testConvertingToMonoRec709Weighted() {
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<2 { for g in 0..<2 { for b in 0..<2 {
            lut.setColor(LUTColor.color(red: 1, green: 0, blue: 0), r: r, g: g, b: b)
        }}}
        let mono = lut.convertingToMono(method: .rec709WeightedRGB)
        let sample = mono.colorAt(r: 0, g: 0, b: 0)
        // saturation=0 with Rec.709 weights on (1,0,0) → luma 0.2126.
        #expect(abs(sample.red - 0.2126) < 1e-9)
        #expect(abs(sample.green - 0.2126) < 1e-9)
        #expect(abs(sample.blue - 0.2126) < 1e-9)
    }

    @Test
    func testConvertingToMonoRedCopied() {
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<2 { for g in 0..<2 { for b in 0..<2 {
            lut.setColor(LUTColor.color(red: 0.4, green: 0.7, blue: 0.9), r: r, g: g, b: b)
        }}}
        let mono = lut.convertingToMono(method: .redCopiedToRGB)
        let sample = mono.colorAt(r: 0, g: 1, b: 0)
        #expect(abs(sample.red - 0.4) < 1e-9)
        #expect(abs(sample.green - 0.4) < 1e-9)
        #expect(abs(sample.blue - 0.4) < 1e-9)
    }

    @Test
    func testConvertingToMonoGreenCopied() {
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<2 { for g in 0..<2 { for b in 0..<2 {
            lut.setColor(LUTColor.color(red: 0.4, green: 0.7, blue: 0.9), r: r, g: g, b: b)
        }}}
        let mono = lut.convertingToMono(method: .greenCopiedToRGB)
        let sample = mono.colorAt(r: 0, g: 1, b: 0)
        #expect(abs(sample.red - 0.7) < 1e-9)
        #expect(abs(sample.green - 0.7) < 1e-9)
        #expect(abs(sample.blue - 0.7) < 1e-9)
    }

    @Test
    func testConvertingToMonoBlueCopied() {
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<2 { for g in 0..<2 { for b in 0..<2 {
            lut.setColor(LUTColor.color(red: 0.4, green: 0.7, blue: 0.9), r: r, g: g, b: b)
        }}}
        let mono = lut.convertingToMono(method: .blueCopiedToRGB)
        let sample = mono.colorAt(r: 0, g: 1, b: 0)
        #expect(abs(sample.red - 0.9) < 1e-9)
        #expect(abs(sample.green - 0.9) < 1e-9)
        #expect(abs(sample.blue - 0.9) < 1e-9)
    }

    @Test
    func testApplyingColorMatrixIdentityIsNoOp() {
        let lut = LUT3D.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let identityMatrix: (Double, Double, Double, Double, Double, Double, Double, Double, Double) =
            (1, 0, 0, 0, 1, 0, 0, 0, 1)
        let result = lut.applyingColorMatrix(columnMajor: identityMatrix)
        #expect(result.equals(lut, tolerance: 1e-9))
    }

    @Test
    func testApplyingColorMatrixSwapsRedAndBlue() {
        // Matrix swapping R↔B: out.r = b, out.g = g, out.b = r.
        // ObjC convention is column-major as (m00=Rr, m01=Rg, m02=Rb, m10=Gr, ...)
        // applied as out.r = m00*r + m01*g + m02*b, etc.
        let swapMatrix: (Double, Double, Double, Double, Double, Double, Double, Double, Double) =
            (0, 0, 1,
             0, 1, 0,
             1, 0, 0)
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(LUTColor.color(red: 0.2, green: 0.5, blue: 0.9), r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 0.1, green: 0.3, blue: 0.7), r: 1, g: 1, b: 1)

        let result = lut.applyingColorMatrix(columnMajor: swapMatrix)
        let s0 = result.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(s0.red - 0.9) < 1e-9)
        #expect(abs(s0.green - 0.5) < 1e-9)
        #expect(abs(s0.blue - 0.2) < 1e-9)

        let s1 = result.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(s1.red - 0.7) < 1e-9)
        #expect(abs(s1.green - 0.3) < 1e-9)
        #expect(abs(s1.blue - 0.1) < 1e-9)
    }

    @Test
    func testApplyingColorMatrixPropagatesMetadata() {
        var identity = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        identity.title = "Source"
        identity.descriptionText = "Description"
        let result = identity.applyingColorMatrix(columnMajor: (1, 0, 0, 0, 1, 0, 0, 0, 1))
        #expect(result.title == "Source")
        #expect(result.descriptionText == "Description")
    }

    @Test
    func testConvertingToMonoPropagatesMetadata() {
        var identity = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        identity.title = "Source"
        identity.descriptionText = "Description"
        let mono = identity.convertingToMono(method: .averageRGB)
        #expect(mono.title == "Source")
        #expect(mono.descriptionText == "Description")
    }

    @Test
    func testExtractingContrastOnlyRebuildsLUTFromDiagonalCurves() {
        // Build a LUT3D where the diagonal is a known curve f(x)=x^2 but
        // off-diagonal points have hue (R,G,B differ). After extractingContrastOnly,
        // every cell (r,g,b) must equal (f(r), f(g), f(b)).
        let size = 4
        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    // Diagonal carries the contrast curve; off-diagonal injects hue.
                    let rd = Double(r) / Double(size - 1)
                    let gd = Double(g) / Double(size - 1)
                    let bd = Double(b) / Double(size - 1)
                    if r == g && g == b {
                        let f = rd * rd
                        lut.setColor(LUTColor.color(red: f, green: f, blue: f), r: r, g: g, b: b)
                    } else {
                        // Hue shift that should NOT survive extractingContrastOnly.
                        lut.setColor(LUTColor.color(red: rd * 0.5,
                                                     green: gd * 0.7,
                                                     blue: bd * 0.9),
                                     r: r, g: g, b: b)
                    }
                }
            }
        }

        let result = lut.extractingContrastOnly()
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let rd = Double(r) / Double(size - 1)
                    let gd = Double(g) / Double(size - 1)
                    let bd = Double(b) / Double(size - 1)
                    let expected = LUTColor.color(red: rd * rd, green: gd * gd, blue: bd * bd)
                    let actual = result.colorAt(r: r, g: g, b: b)
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
