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
        resized.title = title
        resized.descriptionText = descriptionText
        resized.metadata = metadata
        resized.passthroughFileOptions = passthroughFileOptions

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
        newLUT.title = title
        newLUT.descriptionText = descriptionText
        newLUT.metadata = metadata
        newLUT.passthroughFileOptions = passthroughFileOptions

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

    // MARK: - Private Helpers

    // MARK: - Private Helpers

    private func colorInterpolated(r: Double, g: Double, b: Double) -> LUTColor {
        if size == 1 { return storage[0] }
        precondition(r >= 0 && r <= Double(size - 1))
        precondition(g >= 0 && g <= Double(size - 1))
        precondition(b >= 0 && b <= Double(size - 1))

        let r0 = Int(floor(r))
        let g0 = Int(floor(g))
        let b0 = Int(floor(b))

        let r1 = min(r0 + 1, size - 1)
        let g1 = min(g0 + 1, size - 1)
        let b1 = min(b0 + 1, size - 1)

        let dr = r - Double(r0)
        let dg = g - Double(g0)
        let db = b - Double(b0)

        let c000 = colorAt(r: r0, g: g0, b: b0)
        let c100 = colorAt(r: r1, g: g0, b: b0)
        let c010 = colorAt(r: r0, g: g1, b: b0)
        let c110 = colorAt(r: r1, g: g1, b: b0)
        let c001 = colorAt(r: r0, g: g0, b: b1)
        let c101 = colorAt(r: r1, g: g0, b: b1)
        let c011 = colorAt(r: r0, g: g1, b: b1)
        let c111 = colorAt(r: r1, g: g1, b: b1)

        let c00 = c000.lerping(to: c100, amount: dr)
        let c10 = c010.lerping(to: c110, amount: dr)
        let c01 = c001.lerping(to: c101, amount: dr)
        let c11 = c011.lerping(to: c111, amount: dr)

        let c0 = c00.lerping(to: c10, amount: dg)
        let c1 = c01.lerping(to: c11, amount: dg)
        return c0.lerping(to: c1, amount: db)
    }

    private func linearIndex(r: Int, g: Int, b: Int) -> Int {
        precondition((0..<size).contains(r) && (0..<size).contains(g) && (0..<size).contains(b), "Index out of range")
        return ((r * size) + g) * size + b
    }

    private func mapColors(_ transform: (LUTColor) -> LUTColor) -> LUT {
        var result = LUT(size: size, inputLowerBound: inputLowerBound, inputUpperBound: inputUpperBound)
        result.title = title
        result.descriptionText = descriptionText
        result.metadata = metadata
        result.passthroughFileOptions = passthroughFileOptions
        result.storage = storage.map(transform)
        return result
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
