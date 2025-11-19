import Foundation

public struct LUT {
    public var title: String?
    public var descriptionText: String?
    public var metadata: [String: Any]
    public var passthroughFileOptions: [String: Any]

    public let size: Int
    public let inputLowerBound: Double
    public let inputUpperBound: Double

    private var storage: [LUTColor]

    public init(size: Int, inputLowerBound: Double, inputUpperBound: Double, fill color: LUTColor = .zeros()) {
        precondition(size > 0, "Size must be greater than zero")
        precondition(inputUpperBound > inputLowerBound, "Upper bound must be greater than lower bound")

        self.size = size
        self.inputLowerBound = inputLowerBound
        self.inputUpperBound = inputUpperBound
        self.title = nil
        self.descriptionText = nil
        self.metadata = [:]
        self.passthroughFileOptions = [:]

        let elementCount = size * size * size
        self.storage = Array(repeating: color, count: elementCount)
    }

    public static func identity(size: Int, inputLowerBound: Double, inputUpperBound: Double) -> LUT {
        var lut = LUT(size: size, inputLowerBound: inputLowerBound, inputUpperBound: inputUpperBound)
        lut.loop { r, g, b in
            let color = lut.identityColorAt(r: Double(r), g: Double(g), b: Double(b))
            lut.setColor(color, r: r, g: g, b: b)
        }
        return lut
    }

    public func colorAt(r: Int, g: Int, b: Int) -> LUTColor {
        storage[linearIndex(r: r, g: g, b: b)]
    }

    public mutating func setColor(_ color: LUTColor, r: Int, g: Int, b: Int) {
        storage[linearIndex(r: r, g: g, b: b)] = color
    }

    public func loop(_ body: (_ r: Int, _ g: Int, _ b: Int) -> Void) {
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    body(r, g, b)
                }
            }
        }
    }

    public func identityColorAt(r: Double, g: Double, b: Double) -> LUTColor {
        let red = LUTMath.remapNoError(r,
                                       inputLow: 0,
                                       inputHigh: Double(size - 1),
                                       outputLow: inputLowerBound,
                                       outputHigh: inputUpperBound)
        let green = LUTMath.remapNoError(g,
                                         inputLow: 0,
                                         inputHigh: Double(size - 1),
                                         outputLow: inputLowerBound,
                                         outputHigh: inputUpperBound)
        let blue = LUTMath.remapNoError(b,
                                        inputLow: 0,
                                        inputHigh: Double(size - 1),
                                        outputLow: inputLowerBound,
                                        outputHigh: inputUpperBound)
        return LUTColor.color(red: red, green: green, blue: blue)
    }

    public func color(at color: LUTColor) -> LUTColor {
        let clamped = color.clamped(lowerBound: inputLowerBound, upperBound: inputUpperBound)
        let r = LUTMath.remapNoError(clamped.red,
                                      inputLow: inputLowerBound,
                                      inputHigh: inputUpperBound,
                                      outputLow: 0,
                                      outputHigh: Double(size - 1))
        let g = LUTMath.remapNoError(clamped.green,
                                      inputLow: inputLowerBound,
                                      inputHigh: inputUpperBound,
                                      outputLow: 0,
                                      outputHigh: Double(size - 1))
        let b = LUTMath.remapNoError(clamped.blue,
                                      inputLow: inputLowerBound,
                                      inputHigh: inputUpperBound,
                                      outputLow: 0,
                                      outputHigh: Double(size - 1))
        return colorInterpolated(r: LUTMath.clamp(r, lower: 0, upper: Double(size - 1)),
                                 g: LUTMath.clamp(g, lower: 0, upper: Double(size - 1)),
                                 b: LUTMath.clamp(b, lower: 0, upper: Double(size - 1)))
    }

    public func resized(to newSize: Int) -> LUT {
        precondition(newSize > 0, "Size must be greater than zero")
        if newSize == size { return self }

        var resized = LUT(size: newSize, inputLowerBound: inputLowerBound, inputUpperBound: inputUpperBound)
        cloneMetadata(into: &resized)

        let ratio = newSize == 1 ? 0 : Double(size - 1) / Double(newSize - 1)
        for r in 0..<newSize {
            for g in 0..<newSize {
                for b in 0..<newSize {
                    let sourceR = min(Double(size - 1), Double(r) * ratio)
                    let sourceG = min(Double(size - 1), Double(g) * ratio)
                    let sourceB = min(Double(size - 1), Double(b) * ratio)
                    let color = colorInterpolated(r: sourceR, g: sourceG, b: sourceB)
                    resized.setColor(color, r: r, g: g, b: b)
                }
            }
        }

        return resized
    }

    public func equalsIdentity(tolerance: Double) -> Bool {
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let expected = identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                    if colorAt(r: r, g: g, b: b).distance(to: expected) > tolerance {
                        return false
                    }
                }
            }
        }
        return true
    }

    public func equals(_ other: LUT, tolerance: Double = 1e-9) -> Bool {
        guard size == other.size,
              inputLowerBound == other.inputLowerBound,
              inputUpperBound == other.inputUpperBound else { return false }
        for index in 0..<storage.count {
            if storage[index].distance(to: other.storage[index]) > tolerance {
                return false
            }
        }
        return true
    }

    public func changingInputBounds(lower: Double, upper: Double) -> LUT {
        precondition(upper > lower, "Upper bound must be greater than lower bound")
        if lower == inputLowerBound && upper == inputUpperBound {
            return self
        }

    var newLUT = LUT(size: size, inputLowerBound: lower, inputUpperBound: upper)
    cloneMetadata(into: &newLUT)

        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let identity = newLUT.identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                    let color = color(at: identity)
                    newLUT.setColor(color, r: r, g: g, b: b)
                }
            }
        }

        return newLUT
    }

    public func clamped(lower: Double, upper: Double) -> LUT {
        mapColors { $0.clamped(lowerBound: lower, upperBound: upper) }
    }

    public func remappingValues(inputLow: Double,
                                 inputHigh: Double,
                                 outputLow: Double,
                                 outputHigh: Double) -> LUT {
        remappingValues(inputLow: inputLow,
                        inputHigh: inputHigh,
                        outputLow: outputLow,
                        outputHigh: outputHigh,
                        bounded: false)
    }

    public func remappingValues(inputLow: Double,
                                 inputHigh: Double,
                                 outputLow: Double,
                                 outputHigh: Double,
                                 bounded: Bool) -> LUT {
        mapColors { $0.remapped(inputLow: inputLow,
                                inputHigh: inputHigh,
                                outputLow: outputLow,
                                outputHigh: outputHigh,
                                bounded: bounded) }
    }

    public func remappingValues(inputLowColor: LUTColor,
                                 inputHighColor: LUTColor,
                                 outputLowColor: LUTColor,
                                 outputHighColor: LUTColor,
                                 bounded: Bool) -> LUT {
        mapColors { $0.remapped(inputLowColor: inputLowColor,
                                inputHighColor: inputHighColor,
                                outputLowColor: outputLowColor,
                                outputHighColor: outputHighColor,
                                bounded: bounded) }
    }

    public func offsetting(by color: LUTColor) -> LUT {
        mapColors { $0.adding(color) }
    }

    public func applyingColorMatrix(columnMajor matrix: (Double, Double, Double, Double, Double, Double, Double, Double, Double)) -> LUT {
        mapColors { $0.applyingColorMatrix(columnMajor: matrix) }
    }

    public func minimumOutputValue() -> Double {
        storage.reduce(Double.greatestFiniteMagnitude) { partialResult, color in
            min(partialResult, color.minimumValue())
        }
    }

    public func maximumOutputValue() -> Double {
        storage.reduce(-Double.greatestFiniteMagnitude) { partialResult, color in
            max(partialResult, color.maximumValue())
        }
    }

    public func minimumOutputColor() -> LUTColor {
        guard let first = storage.first else { return .zeros() }
        return storage.dropFirst().reduce(first) { result, color in
            LUTColor.color(red: min(result.red, color.red),
                           green: min(result.green, color.green),
                           blue: min(result.blue, color.blue))
        }
    }

    public func maximumOutputColor() -> LUTColor {
        guard let first = storage.first else { return .zeros() }
        return storage.dropFirst().reduce(first) { result, color in
            LUTColor.color(red: max(result.red, color.red),
                           green: max(result.green, color.green),
                           blue: max(result.blue, color.blue))
        }
    }

    public func scaledTo01() -> LUT {
        let minValue = minimumOutputValue()
        let maxValue = maximumOutputValue()
        guard maxValue > minValue else { return self }
        return remappingValues(inputLow: minValue,
                               inputHigh: maxValue,
                               outputLow: 0,
                               outputHigh: 1,
                               bounded: false)
    }

    public func scaledRGBTo01() -> LUT {
        let minColor = minimumOutputColor()
        let maxColor = maximumOutputColor()
        guard maxColor.maximumValue() > minColor.minimumValue() else { return self }
        return remappingValues(inputLowColor: minColor,
                               inputHighColor: maxColor,
                               outputLowColor: .zeros(),
                               outputHighColor: .ones(),
                               bounded: false)
    }

    public func scaledCurvesTo01() -> LUT {
        let extrema = curveScalarExtrema()
        guard let minValue = extrema?.min, let maxValue = extrema?.max, maxValue > minValue else {
            return self
        }
        return remappingValues(inputLow: minValue,
                               inputHigh: maxValue,
                               outputLow: 0,
                               outputHigh: 1,
                               bounded: false)
    }

    public func scaledCurvesRGBTo01() -> LUT {
    guard let extrema = curveColorExtrema(), extrema.max.distance(to: extrema.min) > 0 else { return self }
        return remappingValues(inputLowColor: extrema.min,
                               inputHighColor: extrema.max,
                               outputLowColor: .zeros(),
                               outputHighColor: .ones(),
                               bounded: false)
    }

    public func scaledLegalToExtended() -> LUT {
        remappingValues(inputLow: LUTConstants.legalLevelsMin,
                        inputHigh: LUTConstants.legalLevelsMax,
                        outputLow: LUTConstants.extendedLevelsMin,
                        outputHigh: LUTConstants.extendedLevelsMax,
                        bounded: false)
    }

    public func scaledExtendedToLegal() -> LUT {
        remappingValues(inputLow: LUTConstants.extendedLevelsMin,
                        inputHigh: LUTConstants.extendedLevelsMax,
                        outputLow: LUTConstants.legalLevelsMin,
                        outputHigh: LUTConstants.legalLevelsMax,
                        bounded: false)
    }

    public func combined(with other: LUT, targetSize: Int? = nil) -> LUT {
        let finalSize = targetSize ?? max(self.size, other.size)
        return combined(targetSize: finalSize, other: other, sameSize: finalSize == self.size)
    }

    // MARK: - Private Helpers

    // MARK: - Private Helpers

    public func colorInterpolated(r: Double, g: Double, b: Double) -> LUTColor {
        if size == 1 { return storage[0] }
        precondition(r >= 0 && r <= Double(size - 1))
        precondition(g >= 0 && g <= Double(size - 1))
        precondition(b >= 0 && b <= Double(size - 1))

        let lowerR = Int(floor(r))
        let lowerG = Int(floor(g))
        let lowerB = Int(floor(b))

        let upperR = Int(ceil(r))
        let upperG = Int(ceil(g))
        let upperB = Int(ceil(b))

        let deltaX = r - Double(lowerR)
        let deltaY = g - Double(lowerG)
        let deltaZ = b - Double(lowerB)

        let p000 = colorAt(r: lowerR, g: lowerG, b: lowerB)
        let p001 = colorAt(r: lowerR, g: lowerG, b: upperB)
        let p100 = colorAt(r: upperR, g: lowerG, b: lowerB)
        let p010 = colorAt(r: lowerR, g: upperG, b: lowerB)
        let p101 = colorAt(r: upperR, g: lowerG, b: upperB)
        let p111 = colorAt(r: upperR, g: upperG, b: upperB)
        let p110 = colorAt(r: upperR, g: upperG, b: lowerB)
        let p011 = colorAt(r: lowerR, g: upperG, b: upperB)

        var weights = [Double](repeating: 0, count: 8)

        if deltaX >= deltaY && deltaY >= deltaZ {
            weights[0] = 1.0 - deltaX
            weights[1] = 0
            weights[2] = 0
            weights[3] = 0
            weights[4] = deltaX - deltaY
            weights[5] = 0
            weights[6] = deltaY - deltaZ
            weights[7] = deltaZ
        } else if deltaX >= deltaZ && deltaZ >= deltaY {
            weights[0] = 1.0 - deltaX
            weights[1] = 0
            weights[2] = 0
            weights[3] = 0
            weights[4] = deltaX - deltaZ
            weights[5] = deltaZ - deltaY
            weights[6] = 0
            weights[7] = deltaY
        } else if deltaZ >= deltaX && deltaX >= deltaY {
            weights[0] = 1.0 - deltaZ
            weights[1] = deltaZ - deltaX
            weights[2] = 0
            weights[3] = 0
            weights[4] = 0
            weights[5] = deltaX - deltaY
            weights[6] = 0
            weights[7] = deltaY
        } else if deltaY >= deltaX && deltaX >= deltaZ {
            weights[0] = 1.0 - deltaY
            weights[1] = 0
            weights[2] = deltaY - deltaX
            weights[3] = 0
            weights[4] = 0
            weights[5] = 0
            weights[6] = deltaX - deltaZ
            weights[7] = deltaZ
        } else if deltaY >= deltaZ && deltaZ >= deltaX {
            weights[0] = 1.0 - deltaY
            weights[1] = 0
            weights[2] = deltaY - deltaZ
            weights[3] = deltaZ - deltaX
            weights[4] = 0
            weights[5] = 0
            weights[6] = 0
            weights[7] = deltaX
        } else {
            weights[0] = 1.0 - deltaZ
            weights[1] = deltaZ - deltaY
            weights[2] = 0
            weights[3] = deltaY - deltaX
            weights[4] = 0
            weights[5] = 0
            weights[6] = 0
            weights[7] = deltaX
        }

        let red = weights[0] * p000.red +
                  weights[1] * p001.red +
                  weights[2] * p010.red +
                  weights[3] * p011.red +
                  weights[4] * p100.red +
                  weights[5] * p101.red +
                  weights[6] * p110.red +
                  weights[7] * p111.red

        let green = weights[0] * p000.green +
                    weights[1] * p001.green +
                    weights[2] * p010.green +
                    weights[3] * p011.green +
                    weights[4] * p100.green +
                    weights[5] * p101.green +
                    weights[6] * p110.green +
                    weights[7] * p111.green

        let blue = weights[0] * p000.blue +
                   weights[1] * p001.blue +
                   weights[2] * p010.blue +
                   weights[3] * p011.blue +
                   weights[4] * p100.blue +
                   weights[5] * p101.blue +
                   weights[6] * p110.blue +
                   weights[7] * p111.blue

        return LUTColor.color(red: red, green: green, blue: blue)
    }

    private func linearIndex(r: Int, g: Int, b: Int) -> Int {
        guard (0..<size).contains(r), (0..<size).contains(g), (0..<size).contains(b) else {
            preconditionFailure("Index out of range")
        }
        return ((r * size) + g) * size + b
    }

    func mapColors(_ transform: (LUTColor) -> LUTColor) -> LUT {
        var result = LUT(size: size, inputLowerBound: inputLowerBound, inputUpperBound: inputUpperBound)
        cloneMetadata(into: &result)
        result.storage = storage.map(transform)
        return result
    }

    private func combined(targetSize: Int, other: LUT, sameSize: Bool) -> LUT {
        var result = LUT(size: targetSize,
                         inputLowerBound: inputLowerBound,
                         inputUpperBound: inputUpperBound)
        cloneMetadata(into: &result)

        for r in 0..<targetSize {
            for g in 0..<targetSize {
                for b in 0..<targetSize {
                    let startColor: LUTColor
                    if sameSize {
                        startColor = colorAt(r: r, g: g, b: b)
                    } else {
                        let identity = result.identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                        startColor = color(at: identity)
                    }
                    let newColor = other.color(at: startColor)
                    result.setColor(newColor, r: r, g: g, b: b)
                }
            }
        }

        return result
    }

    func cloneMetadata(into result: inout LUT) {
        result.copyMetadata(from: self)
    }

    private func curveScalarExtrema() -> (min: Double, max: Double)? {
        guard size > 0 else { return nil }
        let colors = (0..<size).map { colorAt(r: $0, g: $0, b: $0) }
        guard let first = colors.first else { return nil }
        var minValue = first.minimumValue()
        var maxValue = first.maximumValue()
        for color in colors.dropFirst() {
            minValue = min(minValue, color.minimumValue())
            maxValue = max(maxValue, color.maximumValue())
        }
        return (minValue, maxValue)
    }

    private func curveColorExtrema() -> (min: LUTColor, max: LUTColor)? {
        guard size > 0 else { return nil }
        let colors = (0..<size).map { colorAt(r: $0, g: $0, b: $0) }
        guard let first = colors.first else { return nil }
        var minColor = first
        var maxColor = first
        for color in colors.dropFirst() {
            minColor = LUTColor.color(red: min(minColor.red, color.red),
                                      green: min(minColor.green, color.green),
                                      blue: min(minColor.blue, color.blue))
            maxColor = LUTColor.color(red: max(maxColor.red, color.red),
                                      green: max(maxColor.green, color.green),
                                      blue: max(maxColor.blue, color.blue))
        }
        return (minColor, maxColor)
    }

    public mutating func copyMetadata(from other: LUT) {
        title = other.title
        descriptionText = other.descriptionText
        metadata = other.metadata
        passthroughFileOptions = other.passthroughFileOptions
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
