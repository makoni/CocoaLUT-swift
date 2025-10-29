import Foundation

public struct LUT1D {
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
        self.redCurve = redCurve.map(Self.sanitize)
        self.greenCurve = greenCurve.map(Self.sanitize)
        self.blueCurve = blueCurve.map(Self.sanitize)
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
        cube.loop { r, g, b in
            let color = LUTColor.color(red: source.redCurve[r],
                                       green: source.greenCurve[g],
                                       blue: source.blueCurve[b])
            cube.setColor(color, r: r, g: g, b: b)
        }
        return cube
    }

    public func rgbCurveArray() -> [[Double]] {
        [redCurve, greenCurve, blueCurve]
    }

    // MARK: - Private Helpers

    private func evaluateCurve(_ curve: [Double], for value: Double) -> Double {
        if size == 1 { return curve[0] }
        let clampedValue = clamp(value, lower: inputLowerBound, upper: inputUpperBound)
        let normalized = remap(clampedValue, inputLowerBound, inputUpperBound, 0, Double(size - 1))
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
        return lerp(curve[lowerIndex], curve[upperIndex], t: t)
    }

    private static func sanitize(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func remap(_ value: Double,
                       _ inputLow: Double,
                       _ inputHigh: Double,
                       _ outputLow: Double,
                       _ outputHigh: Double) -> Double {
        let denominator = inputHigh - inputLow
        guard denominator != 0 else { return outputLow }
        return outputLow + ((value - inputLow) * (outputHigh - outputLow)) / denominator
    }

    private func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * t
    }
}
