import Foundation

public struct LUT3D {
    public enum MonoConversionMethod: CaseIterable, Sendable {
        case averageRGB
        case rec709WeightedRGB
        case redCopiedToRGB
        case greenCopiedToRGB
        case blueCopiedToRGB

        public var displayName: String {
            switch self {
            case .averageRGB: return "Averaged RGB"
            case .rec709WeightedRGB: return "Rec. 709 Weighted RGB"
            case .redCopiedToRGB: return "Copy Red Channel"
            case .greenCopiedToRGB: return "Copy Green Channel"
            case .blueCopiedToRGB: return "Copy Blue Channel"
            }
        }
    }

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

    public static func falseColor(size: Int) -> LUT3D {
        // Mirrors ObjC `+[LUT3D LUT3DFromFalseColorWithSize:]` (LUT3D.m:80-119).
        // Values resolve [NSColor purpleColor]/etc to their deviceRGB components.
        let purple = LUTColor.color(red: 0.5, green: 0, blue: 0.5)
        let blue = LUTColor.color(red: 0, green: 0, blue: 1)
        let green = LUTColor.color(red: 0, green: 1, blue: 0)
        let pink = LUTColor.color(red: 1, green: 0.753, blue: 0.796)
        let yellow = LUTColor.color(red: 1, green: 1, blue: 0)
        let red = LUTColor.color(red: 1, green: 0, blue: 0)

        var lattice = LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let identityColor = lattice.identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                    let lum = identityColor.luminanceRec709()
                    let bucket: LUTColor
                    if lum <= 0.025 {
                        bucket = purple
                    } else if lum <= 0.04 {
                        bucket = blue
                    } else if lum >= 0.38 && lum <= 0.42 {
                        bucket = green
                    } else if lum >= 0.52 && lum <= 0.56 {
                        bucket = pink
                    } else if lum >= 0.97 && lum <= 0.99 {
                        bucket = yellow
                    } else if lum > 0.99 && lum <= 0.100 {
                        // Mirrors ObjC bug at LUT3D.m:111 (`lum > .99 && lum <= .100`)
                        // — never fires because 0.100 == 0.1. Kept for parity.
                        bucket = red
                    } else {
                        bucket = LUTColor.uniform(lum)
                    }
                    lattice.setColor(bucket, r: r, g: g, b: b)
                }
            }
        }
        return LUT3D(lattice: lattice)
    }

    public func applyingColorMatrix(columnMajor matrix: (Double, Double, Double, Double, Double, Double, Double, Double, Double)) -> LUT3D {
        // Mirrors `-LUT3DByApplyingColorMatrixColumnMajorM00:..M22:` (LUT3D.m:221-249).
        var newLattice = lattice
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let transformed = lattice.colorAt(r: r, g: g, b: b)
                        .applyingColorMatrix(columnMajor: matrix)
                    newLattice.setColor(transformed, r: r, g: g, b: b)
                }
            }
        }
        return LUT3D(lattice: newLattice)
    }

    public func convertingToMono(method: MonoConversionMethod) -> LUT3D {
        // Mirrors `-LUT3DByConvertingToMonoWithConversionMethod:` (LUT3D.m:263-298).
        let convert: (LUTColor) -> LUTColor = {
            switch method {
            case .averageRGB:
                return { color in
                    let avg = (color.red + color.green + color.blue) / 3.0
                    return LUTColor.uniform(avg)
                }
            case .rec709WeightedRGB:
                return { color in
                    color.changingSaturation(0, lumaR: 0.2126, lumaG: 0.7152, lumaB: 0.0722)
                }
            case .redCopiedToRGB:
                return { color in LUTColor.uniform(color.red) }
            case .greenCopiedToRGB:
                return { color in LUTColor.uniform(color.green) }
            case .blueCopiedToRGB:
                return { color in LUTColor.uniform(color.blue) }
            }
        }()

        var newLattice = lattice
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    newLattice.setColor(convert(lattice.colorAt(r: r, g: g, b: b)), r: r, g: g, b: b)
                }
            }
        }
        return LUT3D(lattice: newLattice)
    }

    public func extractingContrastOnly() -> LUT3D {
        // Mirrors `-LUT3DByExtractingContrastOnly` (LUT3D.m:205-207):
        // collapse to diagonal 1D curves and re-expand into a 3D lattice.
        toLUT1D().toLUT3D(size: size)
    }

    public func applyingFalseColor() -> LUT3D {
        let falseColorLUT = LUT3D.falseColor(size: size).asLUT()
        var combined = lattice.combined(with: falseColorLUT)
        // `combined(with:)` copies the source's metadata; ensure title/desc forwards.
        combined.title = title
        combined.descriptionText = descriptionText
        combined.metadata = metadata
        combined.passthroughFileOptions = passthroughFileOptions
        return LUT3D(lattice: combined)
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

extension LUT3D {
    public var dataRepresentation: Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        let helper = LUT3DArchivable(self)
        archiver.encode(helper, forKey: NSKeyedArchiveRootObjectKey)
        return archiver.encodedData
    }

    public init(fromDataRepresentation data: Data) throws {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        // Register the helper class for "LUT3D" to support legacy data
        NSKeyedUnarchiver.setClass(LUT3DArchivable.self, forClassName: "LUT3D")
        
        guard let helper = unarchiver.decodeObject(of: LUT3DArchivable.self, forKey: NSKeyedArchiveRootObjectKey) else {
            throw CocoaLUT.Error.invalidFormat("Could not decode LUT3D data")
        }
        self = helper.lut3D
    }

    public func dataFromLUT(withFormatterID formatterID: String, options: [String: Any]? = nil) throws -> Data {
        try lattice.dataFromLUT(withFormatterID: formatterID, options: options)
    }
}

@objc(LUT3DArchivable)
private class LUT3DArchivable: NSObject, NSCoding {
    let lut3D: LUT3D
    
    init(_ lut3D: LUT3D) {
        self.lut3D = lut3D
    }
    
    required init?(coder: NSCoder) {
        let size = coder.decodeInteger(forKey: "size")
        let lower = coder.decodeDouble(forKey: "inputLowerBound")
        let upper = coder.decodeDouble(forKey: "inputUpperBound")
        
        let metadata = coder.decodeObject(forKey: "metadata") as? [String: Any] ?? [:]
        let options = coder.decodeObject(forKey: "passthroughFileOptions") as? [String: Any] ?? [:]
        
        guard let latticeData = coder.decodeObject(forKey: "latticeData") as? Data else {
            return nil
        }
        
        var lut = LUT(size: size, inputLowerBound: lower, inputUpperBound: upper)
        lut.metadata = metadata
        lut.passthroughFileOptions = options
        
        let count = size * size * size
        let expectedBytes = count * 3 * MemoryLayout<Double>.size
        
        if latticeData.count == expectedBytes {
            var colors = [LUTColor]()
            colors.reserveCapacity(count)
            
            latticeData.withUnsafeBytes { buffer in
                let doubles = buffer.bindMemory(to: Double.self)
                for i in 0..<count {
                    colors.append(LUTColor(red: doubles[i*3], green: doubles[i*3+1], blue: doubles[i*3+2]))
                }
            }
            
            var index = 0
            for b in 0..<size {
                for g in 0..<size {
                    for r in 0..<size {
                        if index < colors.count {
                            lut.setColor(colors[index], r: r, g: g, b: b)
                            index += 1
                        }
                    }
                }
            }
        }
        
        self.lut3D = LUT3D(lattice: lut)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(lut3D.size, forKey: "size")
        coder.encode(lut3D.inputLowerBound, forKey: "inputLowerBound")
        coder.encode(lut3D.inputUpperBound, forKey: "inputUpperBound")
        coder.encode(lut3D.metadata, forKey: "metadata")
        coder.encode(lut3D.passthroughFileOptions, forKey: "passthroughFileOptions")
        
        let size = lut3D.size
        let count = size * size * size
        var doubles = [Double]()
        doubles.reserveCapacity(count * 3)
        
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let color = lut3D.colorAt(r: r, g: g, b: b)
                    doubles.append(color.red)
                    doubles.append(color.green)
                    doubles.append(color.blue)
                }
            }
        }
        
        let data = Data(bytes: doubles, count: doubles.count * MemoryLayout<Double>.size)
        coder.encode(data, forKey: "latticeData")
    }
}
