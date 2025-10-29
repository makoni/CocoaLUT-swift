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
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
