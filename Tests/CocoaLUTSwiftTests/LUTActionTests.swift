import XCTest
@testable import CocoaLUT_swift

final class LUTActionTests: XCTestCase {
    private func identityLUT(size: Int = 2) -> LUT {
        LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
    }

    func testCombineActionMatchesDirectCombination() {
        let base = identityLUT()
        let other = base.offsetting(by: LUTColor.color(red: 0.1, green: -0.2, blue: 0.05))

        let action = LUTAction.combine(with: other)
        let result = action.apply(to: base)

        XCTAssertTrue(result.equals(base.combined(with: other), tolerance: 1e-9))
        XCTAssertEqual(action.actionMetadata.value(for: "id") as? String, "Combine")
    }

    func testCombineBehindActionMatchesDirectCombination() {
        let base = identityLUT()
        let other = base.clamped(lower: 0.2, upper: 0.8)

        let action = LUTAction.combineBehind(lut: other)
        let result = action.apply(to: base)

        XCTAssertTrue(result.equals(other.combined(with: base), tolerance: 1e-9))
        XCTAssertEqual(action.actionMetadata.value(for: "id") as? String, "CombineBehind")
    }

    func testApplyColorMatrixSwapsRedAndBlue() {
        var lut = identityLUT()
        lut.setColor(LUTColor.color(red: 0.2, green: 0.4, blue: 0.6), r: 1, g: 1, b: 1)

        let matrix: LUTAction.ColorMatrix = (0, 0, 1,
                                             0, 1, 0,
                                             1, 0, 0)
        let action = LUTAction.applyColorMatrix(matrix)
        let transformed = action.apply(to: lut)
        let color = transformed.colorAt(r: 1, g: 1, b: 1)

        XCTAssertEqual(color.red, 0.6, accuracy: 1e-9)
        XCTAssertEqual(color.green, 0.4, accuracy: 1e-9)
        XCTAssertEqual(color.blue, 0.2, accuracy: 1e-9)
        XCTAssertEqual(action.actionMetadata.value(for: "m02") as? Double, 1)
    }

    func testRemapValuesActionProducesExpectedRange() {
        let action = LUTAction.remapValues(inputLow: 0, inputHigh: 1, outputLow: -1, outputHigh: 1)
        let lut = identityLUT()
        let result = action.apply(to: lut)

        let color = result.colorAt(r: 1, g: 0, b: 0)
        XCTAssertEqual(color.red, 1, accuracy: 1e-9)
        XCTAssertEqual(color.green, -1, accuracy: 1e-9)
        XCTAssertEqual(color.blue, -1, accuracy: 1e-9)
        XCTAssertEqual(action.actionMetadata.value(for: "id") as? String, "ScaleOutput")
    }

    func testOffsetActionEncodesMetadata() {
        let offsetColor = LUTColor.color(red: 0.05, green: -0.1, blue: 0.2)
        let action = LUTAction.offset(by: offsetColor)
        let result = action.apply(to: identityLUT())

        let color = result.colorAt(r: 0, g: 1, b: 1)
        XCTAssertEqual(color.red, 0.05, accuracy: 1e-9)
        XCTAssertEqual(color.green, 0.9, accuracy: 1e-9)
        XCTAssertEqual(color.blue, 1.2, accuracy: 1e-9)
        XCTAssertEqual(action.actionMetadata.value(for: "redOffset") as? Double, offsetColor.red)
    }

    func testCachedApplyCopiesMetadataFromSource() {
        let action = LUTAction.scaleToUnitRange()
        var firstInput = identityLUT()
        firstInput.title = "First"
        let firstResult = action.apply(to: firstInput)
        XCTAssertEqual(firstResult.title, "First")

        var secondInput = firstInput
        secondInput.title = "Second"
        let secondResult = action.apply(to: secondInput)
        XCTAssertEqual(secondResult.title, "Second")
    }

    func testSwizzleActionMatchesManualComposition() {
        let size = 5
        let identity = LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        let matrix: LUTAction.ColorMatrix = (0.8, 0.1, 0.1,
                                             0.2, 0.7, 0.1,
                                             0.1, 0.2, 0.7)
        let colorShift = identity.applyingColorMatrix(columnMajor: matrix)

        let baseCurve = (0..<size).map { pow(Double($0) / Double(size - 1), 1.4) }
        let greenCurve = baseCurve.map { min(1.0, $0 * 0.95) }
        let blueCurve = baseCurve.map { min(1.0, $0 * 1.05) }

        var contrast = LUT1D(redCurve: baseCurve,
                              greenCurve: greenCurve,
                              blueCurve: blueCurve,
                              inputLowerBound: 0,
                              inputUpperBound: 1)
        contrast.title = "Contrast"

        let composed = colorShift.combined(with: contrast.toLUT3D(size: size).asLUT())

        let action = LUTAction.swizzle(method: .averageRGB, strictness: true)
        let result = action.apply(to: composed)

        let expected1D = contrast.swizzled(using: .averageRGB)
        let expected = colorShift.combined(with: expected1D.toLUT3D(size: size).asLUT())

        XCTAssertTrue(result.equals(expected, tolerance: 1e-6))
    }

    func testSwizzleActionReturnsInputWhenNotReversible() {
        let size = 3
        let identity = LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)

        let redCurve: [Double] = [0.0, 0.6, 0.5]
        let monotonic: [Double] = [0.0, 0.5, 1.0]
        let contrast = LUT1D(redCurve: redCurve,
                              greenCurve: monotonic,
                              blueCurve: monotonic,
                              inputLowerBound: 0,
                              inputUpperBound: 1)

        let lut = identity.combined(with: contrast.toLUT3D(size: size).asLUT())

        let action = LUTAction.swizzle(method: .averageRGB, strictness: true)
        let result = action.apply(to: lut)

        XCTAssertTrue(result.equals(lut, tolerance: 1e-9))
    }
}
