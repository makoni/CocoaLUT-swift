import Foundation
import simd

public struct LUTColor: Equatable, Sendable {
    private var components: SIMD3<Double>

    public var red: Double {
        get { components.x }
        set { components.x = Self.sanitize(newValue) }
    }

    public var green: Double {
        get { components.y }
        set { components.y = Self.sanitize(newValue) }
    }

    public var blue: Double {
        get { components.z }
        set { components.z = Self.sanitize(newValue) }
    }

    public init(red: Double, green: Double, blue: Double) {
        self.components = Self.sanitize(SIMD3(red, green, blue))
    }

    private init(components: SIMD3<Double>, alreadySanitized: Bool) {
        self.components = alreadySanitized ? components : Self.sanitize(components)
    }

    // MARK: - Factories

    public static func color(red: Double, green: Double, blue: Double) -> LUTColor {
        LUTColor(red: red, green: green, blue: blue)
    }

    public static func zeros() -> LUTColor {
        LUTColor(red: 0, green: 0, blue: 0)
    }

    public static func ones() -> LUTColor {
        LUTColor(red: 1, green: 1, blue: 1)
    }

    public static func uniform(_ value: Double) -> LUTColor {
        LUTColor(red: value, green: value, blue: value)
    }

    public static func fromIntegers(bitDepth: Int, red: Int, green: Int, blue: Int) -> LUTColor {
        let maxValue = LUTMath.maxInteger(bitDepth: bitDepth)
        guard maxValue > 0 else { return .zeros() }
        let scale = 1.0 / Double(maxValue)
        return LUTColor(red: Double(red) * scale,
                        green: Double(green) * scale,
                        blue: Double(blue) * scale)
    }

    public static func fromIntegers(maxOutputValue: Int, red: Int, green: Int, blue: Int) -> LUTColor {
        guard maxOutputValue > 0 else { return .zeros() }
        let scale = 1.0 / Double(maxOutputValue)
        return LUTColor(red: Double(red) * scale,
                        green: Double(green) * scale,
                        blue: Double(blue) * scale)
    }

    // MARK: - Metrics

    public func minimumValue() -> Double {
        min(red, min(green, blue))
    }

    public func maximumValue() -> Double {
        max(red, max(green, blue))
    }

    // MARK: - Clamping

    public func clamped01() -> LUTColor {
        clamped(lowerBound: 0, upperBound: 1)
    }

    public func clamped(lowerBound: Double, upperBound: Double) -> LUTColor {
        precondition(lowerBound <= upperBound, "Lower bound must be less than or equal to upper bound")
        let result = SIMD3(
            LUTMath.clamp(red, lower: lowerBound, upper: upperBound),
            LUTMath.clamp(green, lower: lowerBound, upper: upperBound),
            LUTMath.clamp(blue, lower: lowerBound, upper: upperBound)
        )
        return LUTColor(components: result, alreadySanitized: false)
    }

    public func clamped(lowerBound: Double) -> LUTColor {
        let lower = SIMD3(repeating: lowerBound)
        return LUTColor(components: max(components, lower), alreadySanitized: false)
    }

    public func clamped(upperBound: Double) -> LUTColor {
        let upper = SIMD3(repeating: upperBound)
        return LUTColor(components: min(components, upper), alreadySanitized: false)
    }

    // MARK: - Transformations

    public func contrastStretched(currentMin: Double, currentMax: Double, finalMin: Double, finalMax: Double) -> LUTColor {
        let result = SIMD3(
            LUTMath.contrastStretch(red,
                                     currentMin: currentMin,
                                     currentMax: currentMax,
                                     finalMin: finalMin,
                                     finalMax: finalMax),
            LUTMath.contrastStretch(green,
                                     currentMin: currentMin,
                                     currentMax: currentMax,
                                     finalMin: finalMin,
                                     finalMax: finalMax),
            LUTMath.contrastStretch(blue,
                                     currentMin: currentMin,
                                     currentMax: currentMax,
                                     finalMin: finalMin,
                                     finalMax: finalMax)
        )
        return LUTColor(components: result, alreadySanitized: false)
    }

    public func remapped(inputLow: Double, inputHigh: Double, outputLow: Double, outputHigh: Double, bounded: Bool) -> LUTColor {
        let mapper = { (value: Double) -> Double in
            let inRange = inputLow...inputHigh
            let source = bounded ? value.clamped(to: inRange) : value
            return LUTMath.remapNoError(source,
                                        inputLow: inputLow,
                                        inputHigh: inputHigh,
                                        outputLow: outputLow,
                                        outputHigh: outputHigh)
        }

        let result = SIMD3(mapper(red), mapper(green), mapper(blue))
        return LUTColor(components: result, alreadySanitized: false)
    }

    public func remapped(inputLowColor: LUTColor, inputHighColor: LUTColor, outputLowColor: LUTColor, outputHighColor: LUTColor, bounded: Bool) -> LUTColor {
        let result = SIMD3(
            remapChannel(index: 0, inputLowColor: inputLowColor, inputHighColor: inputHighColor, outputLowColor: outputLowColor, outputHighColor: outputHighColor, bounded: bounded),
            remapChannel(index: 1, inputLowColor: inputLowColor, inputHighColor: inputHighColor, outputLowColor: outputLowColor, outputHighColor: outputHighColor, bounded: bounded),
            remapChannel(index: 2, inputLowColor: inputLowColor, inputHighColor: inputHighColor, outputLowColor: outputLowColor, outputHighColor: outputHighColor, bounded: bounded)
        )
        return LUTColor(components: result, alreadySanitized: false)
    }

    private func remapChannel(index: Int,
                              inputLowColor: LUTColor,
                              inputHighColor: LUTColor,
                              outputLowColor: LUTColor,
                              outputHighColor: LUTColor,
                              bounded: Bool) -> Double {
        let inputLow = inputLowColor.components[index]
        let inputHigh = inputHighColor.components[index]
        let outputLow = outputLowColor.components[index]
        let outputHigh = outputHighColor.components[index]

        let sourceValue = components[index]
        let range = inputLow...inputHigh
        let value = bounded ? sourceValue.clamped(to: range) : sourceValue
        return LUTMath.remapNoError(value,
                                     inputLow: inputLow,
                                     inputHigh: inputHigh,
                                     outputLow: outputLow,
                                     outputHigh: outputHigh)
    }

    public func multiplied(by scalar: Double) -> LUTColor {
        LUTColor(components: components * scalar, alreadySanitized: false)
    }

    public func multiplied(by color: LUTColor) -> LUTColor {
        LUTColor(components: components * color.components, alreadySanitized: false)
    }

    public func adding(_ color: LUTColor) -> LUTColor {
        LUTColor(components: components + color.components, alreadySanitized: false)
    }

    public func subtracting(_ color: LUTColor) -> LUTColor {
        LUTColor(components: components - color.components, alreadySanitized: false)
    }

    public func changingSaturation(_ saturation: Double, lumaR: Double, lumaG: Double, lumaB: Double) -> LUTColor {
        let luma = red * lumaR + green * lumaG + blue * lumaB
        let result = SIMD3(
            luma + saturation * (red - luma),
            luma + saturation * (green - luma),
            luma + saturation * (blue - luma)
        )
        return LUTColor(components: result, alreadySanitized: false)
    }

    public func applyingSlopeOffsetPower(redSlope: Double,
                                         redOffset: Double,
                                         redPower: Double,
                                         greenSlope: Double,
                                         greenOffset: Double,
                                         greenPower: Double,
                                         blueSlope: Double,
                                         blueOffset: Double,
                                         bluePower: Double) -> LUTColor {
        let sanitizedSlope = SIMD3(max(redSlope, 0), max(greenSlope, 0), max(blueSlope, 0))
        let sanitizedPower = SIMD3(max(redPower, 0), max(greenPower, 0), max(bluePower, 0))
        let offsets = SIMD3(redOffset, greenOffset, blueOffset)

        let input = components * sanitizedSlope + offsets
        let result = SIMD3(pow(input.x, sanitizedPower.x),
                           pow(input.y, sanitizedPower.y),
                           pow(input.z, sanitizedPower.z))
        return LUTColor(components: result, alreadySanitized: false)
    }

    public func lerping(to otherColor: LUTColor, amount: Double) -> LUTColor {
        precondition((0...1).contains(amount), "Lerp amount must be in the range [0, 1]")
        let result = SIMD3(
            LUTMath.lerp(components.x, otherColor.components.x, t: amount),
            LUTMath.lerp(components.y, otherColor.components.y, t: amount),
            LUTMath.lerp(components.z, otherColor.components.z, t: amount)
        )
        return LUTColor(components: result, alreadySanitized: false)
    }

    public func distance(to otherColor: LUTColor) -> Double {
        LUTMath.distance(components, otherColor.components)
    }

    public func applyingColorMatrix(columnMajor matrix: (Double, Double, Double, Double, Double, Double, Double, Double, Double)) -> LUTColor {
        let m00 = matrix.0, m01 = matrix.1, m02 = matrix.2
        let m10 = matrix.3, m11 = matrix.4, m12 = matrix.5
        let m20 = matrix.6, m21 = matrix.7, m22 = matrix.8

    let redResult = m00 * red + m01 * green + m02 * blue
    let greenResult = m10 * red + m11 * green + m12 * blue
    let blueResult = m20 * red + m21 * green + m22 * blue

        return LUTColor(red: redResult, green: greenResult, blue: blueResult)
    }

    // MARK: - Utilities

    public func rgbArray() -> [Double] {
        [red, green, blue]
    }

    // MARK: - Internal Helpers

    private static func sanitize(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func sanitize(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(Self.sanitize(vector.x), Self.sanitize(vector.y), Self.sanitize(vector.z))
    }
}

private extension SIMD3 where Scalar == Double {
    subscript(index: Int) -> Double {
        get {
            switch index {
            case 0: return x
            case 1: return y
            default: return z
            }
        }
        set {
            switch index {
            case 0: x = newValue
            case 1: y = newValue
            default: z = newValue
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
