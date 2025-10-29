import XCTest
@testable import CocoaLUT_swift

final class LUTColorTests: XCTestCase {
    func testFactoryMethodsProduceExpectedValues() {
        let custom = LUTColor.color(red: 0.25, green: 0.5, blue: 0.75)
        XCTAssertEqual(custom.red, 0.25)
        XCTAssertEqual(custom.green, 0.5)
        XCTAssertEqual(custom.blue, 0.75)

        let zero = LUTColor.zeros()
        XCTAssertEqual(zero.red, 0.0)
        XCTAssertEqual(zero.green, 0.0)
        XCTAssertEqual(zero.blue, 0.0)

        let ones = LUTColor.ones()
        XCTAssertEqual(ones.red, 1.0)
        XCTAssertEqual(ones.green, 1.0)
        XCTAssertEqual(ones.blue, 1.0)

        let uniform = LUTColor.uniform(0.42)
        assertEqual(uniform.rgbArray(), [0.42, 0.42, 0.42], accuracy: 1e-12)
    }

    func testIntegerFactoriesRescaleToUnitRange() {
        let fromBitDepth = LUTColor.fromIntegers(bitDepth: 10, red: 0, green: 512, blue: 1023)
        XCTAssertEqual(fromBitDepth.red, 0.0, accuracy: 1e-9)
    XCTAssertEqual(fromBitDepth.green, 512.0 / 1023.0, accuracy: 1e-9)
        XCTAssertEqual(fromBitDepth.blue, 1.0, accuracy: 1e-9)

        let fromMaxValue = LUTColor.fromIntegers(maxOutputValue: 4095, red: 1024, green: 2048, blue: 4095)
        XCTAssertEqual(fromMaxValue.red, 1024.0 / 4095.0, accuracy: 1e-9)
        XCTAssertEqual(fromMaxValue.green, 2048.0 / 4095.0, accuracy: 1e-9)
        XCTAssertEqual(fromMaxValue.blue, 1.0, accuracy: 1e-9)
    }

    func testClampAndExtrema() {
        let sample = LUTColor.color(red: -0.25, green: 0.6, blue: 1.5)
        XCTAssertEqual(sample.minimumValue(), -0.25)
        XCTAssertEqual(sample.maximumValue(), 1.5)

        let clamped = sample.clamped01()
        XCTAssertEqual(clamped.red, 0.0, accuracy: 1e-12)
        XCTAssertEqual(clamped.green, 0.6, accuracy: 1e-12)
        XCTAssertEqual(clamped.blue, 1.0, accuracy: 1e-12)

        let lowerBound = sample.clamped(lowerBound: 0.1, upperBound: 0.9)
        XCTAssertEqual(lowerBound.red, 0.1, accuracy: 1e-12)
        XCTAssertEqual(lowerBound.green, 0.6, accuracy: 1e-12)
        XCTAssertEqual(lowerBound.blue, 0.9, accuracy: 1e-12)

        let lowerOnly = sample.clamped(lowerBound: 0.2)
        XCTAssertEqual(lowerOnly.red, 0.2, accuracy: 1e-12)
        XCTAssertEqual(lowerOnly.green, 0.6, accuracy: 1e-12)
        XCTAssertEqual(lowerOnly.blue, 1.5, accuracy: 1e-12)

        let upperOnly = sample.clamped(upperBound: 0.4)
        XCTAssertEqual(upperOnly.red, -0.25, accuracy: 1e-12)
        XCTAssertEqual(upperOnly.green, 0.4, accuracy: 1e-12)
        XCTAssertEqual(upperOnly.blue, 0.4, accuracy: 1e-12)
    }

    func testContrastStretchAndRemap() {
        let color = LUTColor.color(red: 0.0, green: 0.5, blue: 1.0)
        let stretched = color.contrastStretched(currentMin: 0.0, currentMax: 1.0, finalMin: 0.1, finalMax: 0.9)
        XCTAssertEqual(stretched.red, 0.1, accuracy: 1e-12)
        XCTAssertEqual(stretched.green, 0.5, accuracy: 1e-12)
        XCTAssertEqual(stretched.blue, 0.9, accuracy: 1e-12)

        let bounded = color.remapped(inputLow: 0.0, inputHigh: 1.0, outputLow: -1.0, outputHigh: 1.0, bounded: true)
        XCTAssertEqual(bounded.red, -1.0, accuracy: 1e-12)
        XCTAssertEqual(bounded.green, 0.0, accuracy: 1e-12)
        XCTAssertEqual(bounded.blue, 1.0, accuracy: 1e-12)

        let unclampedSource = LUTColor.color(red: -0.2, green: 0.5, blue: 1.2)
        let unbounded = unclampedSource.remapped(inputLow: 0.0, inputHigh: 1.0, outputLow: -1.0, outputHigh: 1.0, bounded: false)
        XCTAssertEqual(unbounded.red, -1.4, accuracy: 1e-12)
        XCTAssertEqual(unbounded.green, 0.0, accuracy: 1e-12)
        XCTAssertEqual(unbounded.blue, 1.4, accuracy: 1e-12)
    }

    func testRemapWithColorBounds() {
        let color = LUTColor.color(red: 0.25, green: 0.5, blue: 0.75)
        let low = LUTColor.zeros()
        let high = LUTColor.ones()
        let offsetLow = LUTColor.uniform(-0.5)
        let offsetHigh = LUTColor.uniform(0.5)

        let remapped = color.remapped(inputLowColor: low, inputHighColor: high, outputLowColor: offsetLow, outputHighColor: offsetHigh, bounded: true)
    XCTAssertEqual(remapped.red, -0.25, accuracy: 1e-12)
    XCTAssertEqual(remapped.green, 0.0, accuracy: 1e-12)
    XCTAssertEqual(remapped.blue, 0.25, accuracy: 1e-12)
    }

    func testArithmeticOperations() {
        let base = LUTColor.color(red: 0.2, green: 0.4, blue: 0.6)
        let other = LUTColor.color(red: 0.5, green: 0.25, blue: 0.125)

        let multiplied = base.multiplied(by: 2.0)
        assertEqual(multiplied.rgbArray(), [0.4, 0.8, 1.2], accuracy: 1e-12)

        let colorProduct = base.multiplied(by: other)
        assertEqual(colorProduct.rgbArray(), [0.1, 0.1, 0.075], accuracy: 1e-12)

        let sum = base.adding(other)
        assertEqual(sum.rgbArray(), [0.7, 0.65, 0.725], accuracy: 1e-12)

        let difference = base.subtracting(other)
        assertEqual(difference.rgbArray(), [-0.3, 0.15, 0.475], accuracy: 1e-12)
    }

    func testSaturationAndSlopeOffsetPower() {
        let color = LUTColor.color(red: 0.8, green: 0.2, blue: 0.4)
        let desaturated = color.changingSaturation(0.0, lumaR: 0.2126, lumaG: 0.7152, lumaB: 0.0722)
        XCTAssertEqual(desaturated.red, desaturated.green, accuracy: 1e-12)
        XCTAssertEqual(desaturated.green, desaturated.blue, accuracy: 1e-12)

        let applied = color.applyingSlopeOffsetPower(redSlope: 1.0, redOffset: 0.1, redPower: 1.0,
                                                     greenSlope: 1.0, greenOffset: -0.1, greenPower: 2.0,
                                                     blueSlope: 0.5, blueOffset: 0.0, bluePower: 1.0)
        XCTAssertEqual(applied.red, 0.9, accuracy: 1e-12)
        XCTAssertEqual(applied.green, pow(0.1, 2.0), accuracy: 1e-12)
        XCTAssertEqual(applied.blue, 0.2, accuracy: 1e-12)
    }

    func testLerpAndDistance() {
        let start = LUTColor.color(red: 0.0, green: 0.0, blue: 0.0)
        let end = LUTColor.color(red: 1.0, green: 1.0, blue: 1.0)
        let halfway = start.lerping(to: end, amount: 0.5)
        assertEqual(halfway.rgbArray(), [0.5, 0.5, 0.5], accuracy: 1e-12)

        let distance = start.distance(to: end)
        XCTAssertEqual(distance, sqrt(3.0), accuracy: 1e-12)
    }

    func testColorMatrixApplication() {
        let color = LUTColor.color(red: 0.25, green: 0.5, blue: 0.75)
        let identity = color.applyingColorMatrix(columnMajor: (1, 0, 0, 0, 1, 0, 0, 0, 1))
        assertEqual(identity.rgbArray(), color.rgbArray(), accuracy: 1e-12)

        let swapRG = color.applyingColorMatrix(columnMajor: (0, 1, 0,
                                                             1, 0, 0,
                                                             0, 0, 1))
        XCTAssertEqual(swapRG.red, color.green, accuracy: 1e-12)
        XCTAssertEqual(swapRG.green, color.red, accuracy: 1e-12)
        XCTAssertEqual(swapRG.blue, color.blue, accuracy: 1e-12)
    }
}

private func assertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
    zip(lhs, rhs).forEach { a, b in
        XCTAssertEqual(a, b, accuracy: accuracy, file: file, line: line)
    }
}
