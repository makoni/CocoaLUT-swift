import Foundation

public struct LUT3D {
    private var lattice: LUT

    public init(size: Int,
                inputLowerBound: Double,
                inputUpperBound: Double,
                fill color: LUTColor = .zeros()) {
        self.lattice = LUT(size: size,
                           inputLowerBound: inputLowerBound,
                           inputUpperBound: inputUpperBound,
                           fill: color)
    }

    public init(lattice: LUT) {
        self.lattice = lattice
    }

    public static func identity(size: Int,
                                 inputLowerBound: Double,
                                 inputUpperBound: Double) -> LUT3D {
        LUT3D(lattice: LUT.identity(size: size,
                                     inputLowerBound: inputLowerBound,
                                     inputUpperBound: inputUpperBound))
    }

    public var title: String? {
        get { lattice.title }
        set { lattice.title = newValue }
    }

    public var descriptionText: String? {
        get { lattice.descriptionText }
        set { lattice.descriptionText = newValue }
    }

    public var metadata: [String: Any] {
        get { lattice.metadata }
        set { lattice.metadata = newValue }
    }

    public var passthroughFileOptions: [String: Any] {
        get { lattice.passthroughFileOptions }
        set { lattice.passthroughFileOptions = newValue }
    }

    public var size: Int { lattice.size }
    public var inputLowerBound: Double { lattice.inputLowerBound }
    public var inputUpperBound: Double { lattice.inputUpperBound }

    public func colorAt(r: Int, g: Int, b: Int) -> LUTColor {
        lattice.colorAt(r: r, g: g, b: b)
    }

    public func color(at color: LUTColor) -> LUTColor {
        lattice.color(at: color)
    }

    public mutating func setColor(_ color: LUTColor, r: Int, g: Int, b: Int) {
        lattice.setColor(color, r: r, g: g, b: b)
    }

    public func loop(_ body: (_ r: Int, _ g: Int, _ b: Int) -> Void) {
        lattice.loop(body)
    }

    public func equalsIdentity(tolerance: Double) -> Bool {
        lattice.equalsIdentity(tolerance: tolerance)
    }

    public func resized(to newSize: Int) -> LUT3D {
        LUT3D(lattice: lattice.resized(to: newSize))
    }

    public func equals(_ other: LUT3D, tolerance: Double = 1e-9) -> Bool {
        lattice.equals(other.lattice, tolerance: tolerance)
    }

    public func asLUT() -> LUT {
        lattice
    }

    public func toLUT1D() -> LUT1D {
        var lut1D = LUT1D(redCurve: Array(repeating: 0, count: size),
                          greenCurve: Array(repeating: 0, count: size),
                          blueCurve: Array(repeating: 0, count: size),
                          inputLowerBound: inputLowerBound,
                          inputUpperBound: inputUpperBound)
        lut1D.title = title
        lut1D.descriptionText = descriptionText
        lut1D.metadata = metadata
        lut1D.passthroughFileOptions = passthroughFileOptions

        lut1D.fillUsingLattice(from: lattice)
        return lut1D
    }

    public func extractingColorShift(strictness: Bool) -> LUT3D? {
        let base1D = toLUT1D()
        guard base1D.isReversible(strict: strictness) else {
            return nil
        }

    let highResolutionSize = max(base1D.size, 131_072)
        let highResolution1D = base1D.size >= highResolutionSize ? base1D : base1D.resized(to: highResolutionSize)

        var colorShiftLattice = lattice
        let curves = highResolution1D.rgbCurveArray()
        let newLowerBound = base1D.minimumOutputValue()
        let newUpperBound = base1D.maximumOutputValue()

        func inverseComponent(_ value: Double, curve: [Double]) -> Double {
            guard let first = curve.first, let last = curve.last else {
                return value
            }

            let clampedValue = LUTMath.clamp(value, lower: newLowerBound, upper: newUpperBound)

            if clampedValue <= first {
                return highResolution1D.inputLowerBound
            }

            if clampedValue >= last {
                return highResolution1D.inputUpperBound
            }

            var low = 0
            var high = curve.count - 1

            while high - low > 1 {
                let mid = (low + high) / 2
                if curve[mid] <= clampedValue {
                    low = mid
                } else {
                    high = mid
                }
            }

            let lowerValue = LUTMath.remapNoError(Double(low),
                                                  inputLow: 0,
                                                  inputHigh: Double(highResolution1D.size - 1),
                                                  outputLow: highResolution1D.inputLowerBound,
                                                  outputHigh: highResolution1D.inputUpperBound)

            let higherValue = LUTMath.remapNoError(Double(high),
                                                   inputLow: 0,
                                                   inputHigh: Double(highResolution1D.size - 1),
                                                   outputLow: highResolution1D.inputLowerBound,
                                                   outputHigh: highResolution1D.inputUpperBound)

            let denominator = curve[high] - curve[low]
            let rawT = denominator == 0 ? 0 : (clampedValue - curve[low]) / denominator
            let t = LUTMath.clamp(rawT, lower: 0, upper: 1)

            return LUTMath.lerp(lowerValue, higherValue, t: t)
        }

        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let startColor = lattice.colorAt(r: r, g: g, b: b)
                    let red = inverseComponent(startColor.red, curve: curves[0])
                    let green = inverseComponent(startColor.green, curve: curves[1])
                    let blue = inverseComponent(startColor.blue, curve: curves[2])
                    let newColor = LUTColor.color(red: red, green: green, blue: blue)
                    colorShiftLattice.setColor(newColor, r: r, g: g, b: b)
                }
            }
        }

        var extracted = LUT3D(lattice: colorShiftLattice)
        extracted.copyMetadata(from: self)
        return extracted
    }

    public func swizzling1DChannels(method: LUT1D.SwizzleMethod,
                                     strictness: Bool = false) -> LUT3D? {
        guard let colorShift = extractingColorShift(strictness: strictness) else { return nil }
        let swizzled1D = toLUT1D().swizzled(using: method)
        let swizzled3D = swizzled1D.toLUT3D(size: size).asLUT()
        let combined = colorShift.asLUT().combined(with: swizzled3D)
        var result = LUT3D(lattice: combined)
        result.copyMetadata(from: self)
        return result
    }

    private mutating func copyMetadata(from other: LUT3D) {
        title = other.title
        descriptionText = other.descriptionText
        metadata = other.metadata
        passthroughFileOptions = other.passthroughFileOptions
    }
}
