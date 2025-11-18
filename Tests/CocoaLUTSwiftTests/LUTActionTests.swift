import Foundation
import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTActionTests {
    private func identityLUT(size: Int = 2) -> LUT {
        LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
    }

    @Test
    func testChangeInputBoundsActionMatchesDirectResult() {
        let original = identityLUT(size: 4)
        let action = LUTAction.changeInputBounds(lower: -0.5, upper: 1.5)

        let actionResult = action.apply(to: original)
        let expected = original.changingInputBounds(lower: -0.5, upper: 1.5)

        #expect(actionResult.inputLowerBound == -0.5)
        #expect(actionResult.inputUpperBound == 1.5)
        #expect(actionResult.equals(expected, tolerance: 1e-9))
        #expect(action.actionMetadata.value(for: "id") as? String == "ChangeInputBounds")
    }

    @Test
    func testClampActionMatchesDirectResult() {
        var lut = identityLUT(size: 3)
        lut.loop { r, g, b in
            let scalar = Double(r + g + b) / Double(max(1, lut.size - 1) * 3)
            let color = LUTColor.color(red: scalar - 0.25,
                                       green: scalar + 0.25,
                                       blue: scalar + 0.75)
            lut.setColor(color, r: r, g: g, b: b)
        }

        let action = LUTAction.clamp(lower: 0, upper: 1)
        let actionResult = action.apply(to: lut)
        let expected = lut.clamped(lower: 0, upper: 1)

        lut.loop { r, g, b in
            let color = actionResult.colorAt(r: r, g: g, b: b)
            #expect(color.red >= 0 - 1e-9)
            #expect(color.red <= 1 + 1e-9)
            #expect(color.green >= 0 - 1e-9)
            #expect(color.green <= 1 + 1e-9)
            #expect(color.blue >= 0 - 1e-9)
            #expect(color.blue <= 1 + 1e-9)
        }

        #expect(actionResult.equals(expected, tolerance: 1e-9))
        #expect(action.actionMetadata.value(for: "id") as? String == "Clamp")
    }

    @Test
    func testResizeActionMatchesDirectResult() {
        var lut = identityLUT(size: 2)
        lut.setColor(LUTColor.color(red: 0.1, green: 0.4, blue: 0.7), r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 0.9, green: 0.6, blue: 0.3), r: 1, g: 1, b: 1)

        let action = LUTAction.resize(to: 5)
        let actionResult = action.apply(to: lut)
        let expected = lut.resized(to: 5)

        #expect(actionResult.size == 5)
        #expect(actionResult.equals(expected, tolerance: 1e-9))
        #expect(action.actionMetadata.value(for: "id") as? String == "Resize")
    }

    @Test
    func testCombineActionMatchesDirectCombination() {
        var base = identityLUT()
        base.metadata["tag"] = "base"
        let other = base.offsetting(by: LUTColor.color(red: 0.1, green: -0.2, blue: 0.05))

        let action = LUTAction.combine(with: other)
        let result = action.apply(to: base)

        #expect(result.equals(base.combined(with: other), tolerance: 1e-9))
        #expect(action.actionMetadata.value(for: "id") as? String == "Combine")
        #expect(result.metadata["tag"] as? String == "base")
    }

    @Test
    func testCombineBehindActionMatchesDirectCombination() {
        var base = identityLUT()
        base.metadata["tag"] = "base"
        let other = base.clamped(lower: 0.2, upper: 0.8)

        let action = LUTAction.combineBehind(lut: other)
        let result = action.apply(to: base)

        #expect(result.equals(other.combined(with: base), tolerance: 1e-9))
        #expect(action.actionMetadata.value(for: "id") as? String == "CombineBehind")
        #expect(result.metadata["tag"] as? String == "base")
    }

    @Test
    func testApplyColorMatrixSwapsRedAndBlue() {
        var lut = identityLUT()
        lut.setColor(LUTColor.color(red: 0.2, green: 0.4, blue: 0.6), r: 1, g: 1, b: 1)

        let matrix: LUTAction.ColorMatrix = (0, 0, 1,
                                             0, 1, 0,
                                             1, 0, 0)
        let action = LUTAction.applyColorMatrix(matrix)
        let transformed = action.apply(to: lut)
        let color = transformed.colorAt(r: 1, g: 1, b: 1)

        #expect(abs(color.red - 0.6) < 1e-9)
        #expect(abs(color.green - 0.4) < 1e-9)
        #expect(abs(color.blue - 0.2) < 1e-9)
        #expect(action.actionMetadata.value(for: "m02") as? Double == 1)
    }

    @Test
    func testRemapValuesActionProducesExpectedRange() {
        let action = LUTAction.remapValues(inputLow: 0, inputHigh: 1, outputLow: -1, outputHigh: 1)
        let lut = identityLUT()
        let result = action.apply(to: lut)

        let color = result.colorAt(r: 1, g: 0, b: 0)
        #expect(abs(color.red - 1) < 1e-9)
        #expect(abs(color.green - -1) < 1e-9)
        #expect(abs(color.blue - -1) < 1e-9)
        #expect(action.actionMetadata.value(for: "id") as? String == "ScaleOutput")
    }

    @Test
    func testOffsetActionEncodesMetadata() {
        let offsetColor = LUTColor.color(red: 0.05, green: -0.1, blue: 0.2)
        let action = LUTAction.offset(by: offsetColor)
        let result = action.apply(to: identityLUT())

        let color = result.colorAt(r: 0, g: 1, b: 1)
        #expect(abs(color.red - 0.05) < 1e-9)
        #expect(abs(color.green - 0.9) < 1e-9)
        #expect(abs(color.blue - 1.2) < 1e-9)
        #expect(action.actionMetadata.value(for: "redOffset") as? Double == offsetColor.red)
    }

    @Test
    func testCachedApplyCopiesMetadataFromSource() {
        let action = LUTAction.scaleToUnitRange()
        var firstInput = identityLUT()
        firstInput.title = "First"
        firstInput.metadata["owner"] = "one"
        let firstResult = action.apply(to: firstInput)
        #expect(firstResult.title == "First")
        #expect(firstResult.metadata["owner"] as? String == "one")

        var secondInput = firstInput
        secondInput.title = "Second"
        secondInput.metadata["owner"] = "two"
        let secondResult = action.apply(to: secondInput)
        #expect(secondResult.title == "Second")
        #expect(secondResult.metadata["owner"] as? String == "two")

        #expect(firstResult.metadata["owner"] as? String == "one")
    }

    @Test
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

        if !result.equals(expected, tolerance: 1e-6) {
            let returnedInput = result.equals(composed, tolerance: 1e-9)
            var maxDistance = 0.0
            for r in 0..<result.size {
                for g in 0..<result.size {
                    for b in 0..<result.size {
                        let dist = result.colorAt(r: r, g: g, b: b).distance(to: expected.colorAt(r: r, g: g, b: b))
                        maxDistance = max(maxDistance, dist)
                    }
                }
            }
            let composed3D = LUT3D(lattice: composed)
            let base1DSource = composed3D.toLUT1D()
            let reversible = base1DSource.isReversible(strict: true)
            var colorShiftDelta = "n/a"
            var sampleMessage = ""
            if let extractedShift = composed3D.extractingColorShift(strictness: true)?.asLUT() {
                var maxShift = 0.0
                for r in 0..<size {
                    for g in 0..<size {
                        for b in 0..<size {
                            let dist = extractedShift.colorAt(r: r, g: g, b: b).distance(to: colorShift.colorAt(r: r, g: g, b: b))
                            maxShift = max(maxShift, dist)
                        }
                    }
                }
                colorShiftDelta = String(maxShift)
                let sample = extractedShift.colorAt(r: 2, g: 2, b: 2)
                let expectedSample = colorShift.colorAt(r: 2, g: 2, b: 2)
                sampleMessage = ", extractedSample=\(sample), expectedSample=\(expectedSample)"
            }

            let base1D = base1DSource.swizzled(using: .averageRGB)
            var oneDDifference = 0.0
            for index in 0..<size {
                let dist = base1D.colorAt(index: index).distance(to: contrast.swizzled(using: .averageRGB).colorAt(index: index))
                oneDDifference = max(oneDDifference, dist)
            }

            let originalSample = base1DSource.colorAt(index: 2)
            let reversedSample = base1DSource.reversed(strictness: true, autoAdjustInputBounds: true)?.colorAt(index: 2)

            let firstFive = (0..<min(5, base1DSource.size)).map { base1DSource.colorAt(index: $0) }
            let reversedFive = base1DSource.reversed(strictness: true, autoAdjustInputBounds: true)?.rgbCurveArray().map { Array($0.prefix(5)) }
            let minOutput = base1DSource.minimumOutputValue()
            let maxOutput = base1DSource.maximumOutputValue()
            let workingLUT = base1DSource.resized(to: max(2048, base1DSource.size))
            let workingFirst = (0..<5).map { workingLUT.colorAt(index: $0) }

            func manualReverseFull(_ lut: LUT1D) -> (LUT1D, [Double], [Double]) {
                let workingLUT = lut.size >= 2048 ? lut : lut.resized(to: 2048)
                let curve = workingLUT.rgbCurveArray()[0]
                let newLowerBound = lut.minimumOutputValue()
                let newUpperBound = lut.maximumOutputValue()
                var result: [Double] = []
                result.reserveCapacity(workingLUT.size)
                var lastJ = 1
                for i in 0..<workingLUT.size {
                    let remappedIndex = LUTMath.remapNoError(Double(i),
                                                             inputLow: 0,
                                                             inputHigh: Double(workingLUT.size - 1),
                                                             outputLow: newLowerBound,
                                                             outputHigh: newUpperBound)

                    if remappedIndex <= (curve.min() ?? newLowerBound) {
                        result.append(lut.inputLowerBound)
                        lastJ = max(1, lastJ)
                        continue
                    }

                    if remappedIndex >= (curve.max() ?? newUpperBound) {
                        result.append(lut.inputUpperBound)
                        lastJ = max(1, lastJ)
                        continue
                    }

                    var appended = false
                    let startJ = max(1, lastJ)
                    for j in startJ..<workingLUT.size {
                        let currentValue = curve[j]
                        if currentValue > remappedIndex {
                            let previousValue = curve[j - 1]
                            let lowerValue = LUTMath.remapNoError(Double(j - 1),
                                                                  inputLow: 0,
                                                                  inputHigh: Double(workingLUT.size - 1),
                                                                  outputLow: workingLUT.inputLowerBound,
                                                                  outputHigh: workingLUT.inputUpperBound)
                            let higherValue = LUTMath.remapNoError(Double(j),
                                                                   inputLow: 0,
                                                                   inputHigh: Double(workingLUT.size - 1),
                                                                   outputLow: workingLUT.inputLowerBound,
                                                                   outputHigh: workingLUT.inputUpperBound)
                            let denominator = currentValue - previousValue
                            let t = denominator == 0 ? 0 : (remappedIndex - previousValue) / denominator
                            let interpolated = LUTMath.lerp(lowerValue, higherValue, t: LUTMath.clamp(t, lower: 0, upper: 1))
                            result.append(interpolated)
                            lastJ = j
                            appended = true
                            break
                        }
                    }

                    if !appended {
                        result.append(workingLUT.inputUpperBound)
                    }
                }
                var manual = LUT1D(redCurve: result,
                                   greenCurve: result,
                                   blueCurve: result,
                                   inputLowerBound: newLowerBound,
                                   inputUpperBound: newUpperBound)
                let sampleIndices: [Int] = [0, 1, 2, 32, 64, 128, 256, 512, 1024, 2047]
                let preResizeSamples = sampleIndices.map { index -> Double in
                    guard index < result.count else { return -1 }
                    return result[index]
                }
                let positions = (0..<lut.size).map { index -> Double in
                    if lut.size == 1 { return 0 }
                    return Double(index) * Double(workingLUT.size - 1) / Double(lut.size - 1)
                }
                let interpolated = positions.prefix(5).map { position -> Double in
                    let lowerIndex = Int(floor(position))
                    let upperIndex = min(lowerIndex + 1, result.count - 1)
                    let t = position - Double(lowerIndex)
                    let lower = result[lowerIndex]
                    let upper = result[upperIndex]
                    return lower + (upper - lower) * t
                }
                manual = manual.resized(to: lut.size)
                return (manual, preResizeSamples, Array(interpolated))
            }
            let (manualReversed, manualPreResizeSamples, manualInterpolatedSamples) = manualReverseFull(base1DSource)
            let manualReverseFirstFiveValues = (0..<5).map { manualReversed.colorAt(index: $0).red }

            #expect(Bool(false), "Swizzle mismatch max distance \(maxDistance), returnedInput=\(returnedInput), reversible=\(reversible), colorShiftDelta=\(colorShiftDelta), swizzled1DDiff=\(oneDDifference), originalSample=\(originalSample), reversedSample=\(String(describing: reversedSample)), firstFive=\(firstFive), workingFirstFive=\(workingFirst), manualPreResizeSamples=\(manualPreResizeSamples), manualInterpolatedSamples=\(manualInterpolatedSamples), manualReverseFirstFive=\(manualReverseFirstFiveValues), reversedFirstFive=\(String(describing: reversedFive)), outputRange=(\(minOutput), \(maxOutput)), resultBounds=(\(result.inputLowerBound), \(result.inputUpperBound)), expectedBounds=(\(expected.inputLowerBound), \(expected.inputUpperBound)))\(sampleMessage)")
        }
    }

    @Test
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

        #expect(result.equals(lut, tolerance: 1e-9))
    }

    @Test
    func testConvertColorTemperatureMatchesUtility() throws {
        let size = 5
        var base = LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        base.title = "Base"
        base.metadata["note"] = "metadata"

        let sourceColorSpace = LUTColorSpace.rec709
        let transfer = LUTColorTransferFunction.gammaTransferFunction(gamma: 2.2)
        let sourceTemperature = try #require(LUTColorSpaceWhitePoint.fromColorTemperature(5600))
        let destinationTemperature = try #require(LUTColorSpaceWhitePoint.fromColorTemperature(3200))

        let action = LUTAction.convertColorTemperature(sourceColorSpace: sourceColorSpace,
                                                        sourceTransferFunction: transfer,
                                                        sourceColorTemperature: sourceTemperature,
                                                        destinationColorTemperature: destinationTemperature)

        let result = action.apply(to: base)

        let expected3D = try LUTColorSpace.convertColorTemperature(LUT3D(lattice: base),
                                                                    sourceColorSpace: sourceColorSpace,
                                                                    sourceTransferFunction: transfer,
                                                                    sourceColorTemperature: sourceTemperature,
                                                                    destinationColorTemperature: destinationTemperature)
        let expected = expected3D.asLUT()

        #expect(result.equals(expected, tolerance: 1e-6))
        #expect(result.title == base.title)
        #expect(result.metadata["note"] as? String == "metadata")

        #expect(action.actionMetadata.value(for: "id") as? String == "ConvertColorTemperature")
        #expect(action.actionMetadata.value(for: "sourceColorSpace") as? String == sourceColorSpace.name)
        #expect(action.actionMetadata.value(for: "sourceTransferFunction") as? String == transfer.name)
        #expect(action.actionMetadata.value(for: "sourceColorTemperature") as? String == sourceTemperature.name)
        #expect(action.actionMetadata.value(for: "destinationColorTemperature") as? String == destinationTemperature.name)
    }
}
