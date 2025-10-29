import Foundation

public struct LUT1D {
    public enum SwizzleMethod: CaseIterable, Sendable {
        case averageRGB
        case rec709WeightedRGB
        case redCopiedToRGB
        case greenCopiedToRGB
        case blueCopiedToRGB

        var displayName: String {
            switch self {
            case .averageRGB:
                return "Averaged RGB"
            case .rec709WeightedRGB:
                return "Rec. 709 Weighted RGB"
            case .redCopiedToRGB:
                return "Copy Red Channel"
            case .greenCopiedToRGB:
                return "Copy Green Channel"
            case .blueCopiedToRGB:
                return "Copy Blue Channel"
            }
        }
    }

    public var title: String?
    public var descriptionText: String?
    public var metadata: [String: Any]
    public var passthroughFileOptions: [String: Any]

    public let size: Int
    public let inputLowerBound: Double
    public let inputUpperBound: Double

    private var redCurve: [Double]
    private var greenCurve: [Double]
    private var blueCurve: [Double]

    public init(redCurve: [Double],
                greenCurve: [Double],
                blueCurve: [Double],
                inputLowerBound: Double,
                inputUpperBound: Double) {
        precondition(!redCurve.isEmpty, "Curves must contain at least one sample")
        precondition(redCurve.count == greenCurve.count && redCurve.count == blueCurve.count, "Curves must have the same number of samples")
        precondition(inputUpperBound > inputLowerBound, "Upper bound must be greater than lower bound")

        self.size = redCurve.count
        self.inputLowerBound = inputLowerBound
        self.inputUpperBound = inputUpperBound
        self.title = nil
        self.descriptionText = nil
        self.metadata = [:]
        self.passthroughFileOptions = [:]
        self.redCurve = Self.sanitized(curve: redCurve)
        self.greenCurve = Self.sanitized(curve: greenCurve)
        self.blueCurve = Self.sanitized(curve: blueCurve)
    }

    public static func uniformCurve(size: Int,
                                    inputLowerBound: Double,
                                    inputUpperBound: Double) -> LUT1D {
        let values = stride(from: 0, to: size, by: 1).map { index -> Double in
            let position = size == 1 ? 0.0 : Double(index) / Double(size - 1)
            return position
        }
        return LUT1D(redCurve: values,
                     greenCurve: values,
                     blueCurve: values,
                     inputLowerBound: inputLowerBound,
                     inputUpperBound: inputUpperBound)
    }

    public func valueAtR(_ index: Int) -> Double {
        redCurve[index]
    }

    public func valueAtG(_ index: Int) -> Double {
        greenCurve[index]
    }

    public func valueAtB(_ index: Int) -> Double {
        blueCurve[index]
    }

    public func color(at color: LUTColor) -> LUTColor {
        let red = evaluateCurve(redCurve, for: color.red)
        let green = evaluateCurve(greenCurve, for: color.green)
        let blue = evaluateCurve(blueCurve, for: color.blue)
        return LUTColor.color(red: red, green: green, blue: blue)
    }

    public func resized(to newSize: Int) -> LUT1D {
        precondition(newSize > 0, "Size must be greater than zero")
        if newSize == size { return self }

        let positions = (0..<newSize).map { index -> Double in
            if newSize == 1 { return 0 }
            return Double(index) * Double(size - 1) / Double(newSize - 1)
        }

    let red = positions.map { evaluateCurve(redCurve, atNormalizedIndex: $0) }
    let green = positions.map { evaluateCurve(greenCurve, atNormalizedIndex: $0) }
    let blue = positions.map { evaluateCurve(blueCurve, atNormalizedIndex: $0) }

        var resized = LUT1D(redCurve: red,
                             greenCurve: green,
                             blueCurve: blue,
                             inputLowerBound: inputLowerBound,
                             inputUpperBound: inputUpperBound)
        resized.title = title
        resized.descriptionText = descriptionText
        resized.metadata = metadata
        resized.passthroughFileOptions = passthroughFileOptions
        return resized
    }

    public func toLUT3D(size newSize: Int) -> LUT3D {
        var cube = LUT3D(size: newSize,
                         inputLowerBound: inputLowerBound,
                         inputUpperBound: inputUpperBound)
        cube.title = title
        cube.descriptionText = descriptionText
        cube.metadata = metadata
        cube.passthroughFileOptions = passthroughFileOptions

        let source = resized(to: newSize)
        for r in 0..<newSize {
            for g in 0..<newSize {
                for b in 0..<newSize {
                    let color = LUTColor.color(red: source.redCurve[r],
                                               green: source.greenCurve[g],
                                               blue: source.blueCurve[b])
                    cube.setColor(color, r: r, g: g, b: b)
                }
            }
        }
        return cube
    }

    public func rgbCurveArray() -> [[Double]] {
        [redCurve, greenCurve, blueCurve]
    }

    public func colorAt(index: Int) -> LUTColor {
        LUTColor.color(red: redCurve[index], green: greenCurve[index], blue: blueCurve[index])
    }

    public mutating func setColor(_ color: LUTColor, index: Int) {
        redCurve[index] = Self.sanitize(color.red)
        greenCurve[index] = Self.sanitize(color.green)
        blueCurve[index] = Self.sanitize(color.blue)
    }

    mutating func fillUsingLattice(from lut: LUT) {
        precondition(lut.size == size, "Size mismatch when converting LUT3D to LUT1D")
        for index in 0..<size {
            let color = lut.colorAt(r: index, g: index, b: index)
            setColor(color, index: index)
        }
    }

    public func minimumOutputValue() -> Double {
        guard let minRed = redCurve.min(),
              let minGreen = greenCurve.min(),
              let minBlue = blueCurve.min() else {
            return 0
        }
        return min(minRed, min(minGreen, minBlue))
    }

    public func maximumOutputValue() -> Double {
        guard let maxRed = redCurve.max(),
              let maxGreen = greenCurve.max(),
              let maxBlue = blueCurve.max() else {
            return 0
        }
        return max(maxRed, max(maxGreen, maxBlue))
    }

    public func isReversible(strict: Bool) -> Bool {
        var isIncreasing = true

        for curve in rgbCurveArray() {
            guard let first = curve.first else { continue }
            var lastValue = first
            for value in curve.dropFirst() {
                if value <= lastValue {
                    if strict || value != lastValue {
                        isIncreasing = false
                        break
                    }
                }
                lastValue = value
            }
            if !isIncreasing { break }
        }

        return isIncreasing
    }

    public func reversed(strictness: Bool,
                         autoAdjustInputBounds: Bool) -> LUT1D? {
        guard isReversible(strict: strictness) else { return nil }

        let workingLUT: LUT1D = size >= 2048 ? self : resized(to: 2048)
        let curves = workingLUT.rgbCurveArray()

        let newLowerBound = minimumOutputValue()
        let newUpperBound = maximumOutputValue()

        var newRGBCurves: [[Double]] = []

        for curve in curves {
            guard let minValue = curve.min(), let maxValue = curve.max() else {
                newRGBCurves.append(Array(repeating: workingLUT.inputLowerBound, count: workingLUT.size))
                continue
            }

            var newCurve: [Double] = []
            newCurve.reserveCapacity(workingLUT.size)
            var lastJ = 1

            for i in 0..<workingLUT.size {
                let remappedIndex = LUTMath.remapNoError(Double(i),
                                                         inputLow: 0,
                                                         inputHigh: Double(workingLUT.size - 1),
                                                         outputLow: newLowerBound,
                                                         outputHigh: newUpperBound)

                if remappedIndex <= minValue {
                    newCurve.append(workingLUT.inputLowerBound)
                    lastJ = max(1, lastJ)
                    continue
                }

                if remappedIndex >= maxValue {
                    newCurve.append(workingLUT.inputUpperBound)
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
                        newCurve.append(interpolated)
                        lastJ = j
                        appended = true
                        break
                    }
                }

                if !appended {
                    newCurve.append(workingLUT.inputUpperBound)
                }
            }

            newRGBCurves.append(newCurve)
        }

        var newLUT = LUT1D(redCurve: newRGBCurves[0],
                            greenCurve: newRGBCurves[1],
                            blueCurve: newRGBCurves[2],
                            inputLowerBound: newLowerBound,
                            inputUpperBound: newUpperBound)
        newLUT = newLUT.resized(to: size)
        newLUT.propagateMetadata(from: self)

        if autoAdjustInputBounds,
           (inputLowerBound < newLUT.inputLowerBound || inputUpperBound > newLUT.inputUpperBound) {
            let adjustedLower = min(inputLowerBound, newLUT.inputLowerBound)
            let adjustedUpper = max(inputUpperBound, newLUT.inputUpperBound)
            newLUT = newLUT.changingInputBounds(lower: adjustedLower, upper: adjustedUpper)
        }

        return newLUT
    }

    public func swizzled(using method: SwizzleMethod) -> LUT1D {
        var red: [Double] = []
        var green: [Double] = []
        var blue: [Double] = []
        red.reserveCapacity(size)
        green.reserveCapacity(size)
        blue.reserveCapacity(size)

        for index in 0..<size {
            let color = colorAt(index: index)
            let transformed: LUTColor
            switch method {
            case .averageRGB:
                let average = (color.red + color.green + color.blue) / 3.0
                transformed = LUTColor.color(red: average, green: average, blue: average)
            case .rec709WeightedRGB:
                let weighted = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
                transformed = LUTColor.color(red: weighted, green: weighted, blue: weighted)
            case .redCopiedToRGB:
                transformed = LUTColor.color(red: color.red, green: color.red, blue: color.red)
            case .greenCopiedToRGB:
                transformed = LUTColor.color(red: color.green, green: color.green, blue: color.green)
            case .blueCopiedToRGB:
                transformed = LUTColor.color(red: color.blue, green: color.blue, blue: color.blue)
            }
            red.append(transformed.red)
            green.append(transformed.green)
            blue.append(transformed.blue)
        }

        var swizzled = LUT1D(redCurve: red,
                              greenCurve: green,
                              blueCurve: blue,
                              inputLowerBound: inputLowerBound,
                              inputUpperBound: inputUpperBound)
        swizzled.propagateMetadata(from: self)
        return swizzled
    }

    public func changingInputBounds(lower: Double, upper: Double) -> LUT1D {
        precondition(upper > lower, "Upper bound must be greater than lower bound")
        if lower == inputLowerBound && upper == inputUpperBound { return self }

        var red: [Double] = []
        var green: [Double] = []
        var blue: [Double] = []
        red.reserveCapacity(size)
        green.reserveCapacity(size)
        blue.reserveCapacity(size)

        for index in 0..<size {
            let inputValue: Double
            if size == 1 {
                inputValue = lower
            } else {
                inputValue = LUTMath.remapNoError(Double(index),
                                                  inputLow: 0,
                                                  inputHigh: Double(size - 1),
                                                  outputLow: lower,
                                                  outputHigh: upper)
            }
            let color = color(at: LUTColor.color(red: inputValue, green: inputValue, blue: inputValue))
            red.append(color.red)
            green.append(color.green)
            blue.append(color.blue)
        }

        var adjusted = LUT1D(redCurve: red,
                              greenCurve: green,
                              blueCurve: blue,
                              inputLowerBound: lower,
                              inputUpperBound: upper)
        adjusted.propagateMetadata(from: self)
        return adjusted
    }

    private mutating func propagateMetadata(from other: LUT1D) {
        title = other.title
        descriptionText = other.descriptionText
        metadata = other.metadata
        passthroughFileOptions = other.passthroughFileOptions
    }

    // MARK: - Private Helpers

    private func evaluateCurve(_ curve: [Double], for value: Double) -> Double {
        if size == 1 { return curve[0] }
        let clampedValue = LUTMath.clamp(value, lower: inputLowerBound, upper: inputUpperBound)
        let normalized = LUTMath.remapNoError(clampedValue,
                                              inputLow: inputLowerBound,
                                              inputHigh: inputUpperBound,
                                              outputLow: 0,
                                              outputHigh: Double(size - 1))
        return evaluateCurve(curve, atNormalizedIndex: normalized)
    }

    private func evaluateCurve(_ curve: [Double], atNormalizedIndex index: Double) -> Double {
        if size == 1 { return curve[0] }
        let lowerIndex = Int(floor(index))
        let upperIndex = Int(ceil(index))
        if lowerIndex == upperIndex {
            return curve[lowerIndex]
        }
        let t = index - Double(lowerIndex)
        return LUTMath.lerp(curve[lowerIndex], curve[upperIndex], t: t)
    }

    private static func sanitize(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func sanitized(curve: [Double]) -> [Double] {
        curve.map(Self.sanitize)
    }
}

    extension LUT1D: @unchecked Sendable {}
