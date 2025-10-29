import CoreGraphics
import Foundation
import simd

#if canImport(UIKit)
import UIKit
public typealias SystemColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias SystemColor = NSColor
#else
public struct SystemColor { }
#endif

enum LUTMath {
    static func contrastStretch(_ value: Double,
                                 currentMin: Double,
                                 currentMax: Double,
                                 finalMin: Double,
                                 finalMax: Double) -> Double {
        let denominator = currentMax - currentMin
        guard denominator != 0 else { return finalMin }
        return (value - currentMin) * ((finalMax - finalMin) / denominator) + finalMin
    }

    static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    static func clamp01(_ value: Double) -> Double {
        clamp(value, lower: 0, upper: 1)
    }

    static func clampLowerBound(_ value: Double, lowerBound: Double) -> Double {
        max(value, lowerBound)
    }

    static func clampUpperBound(_ value: Double, upperBound: Double) -> Double {
        min(value, upperBound)
    }

    static func remap(_ value: Double,
                      inputLow: Double,
                      inputHigh: Double,
                      outputLow: Double,
                      outputHigh: Double) -> Double {
        precondition(value >= inputLow && value <= inputHigh, "Value out of bounds for remap")
        precondition(inputLow <= inputHigh, "Input lower bound must not exceed upper bound")
        precondition(outputLow <= outputHigh, "Output lower bound must not exceed upper bound")
        return remapNoError(value,
                            inputLow: inputLow,
                            inputHigh: inputHigh,
                            outputLow: outputLow,
                            outputHigh: outputHigh)
    }

    static func remapNoError(_ value: Double,
                             inputLow: Double,
                             inputHigh: Double,
                             outputLow: Double,
                             outputHigh: Double) -> Double {
        let denominator = inputHigh - inputLow
        guard denominator != 0 else { return outputLow }
        return outputLow + ((value - inputLow) * (outputHigh - outputLow)) / denominator
    }

    static func remapInt01(_ value: Int, maxValue: Int) -> Double {
        guard maxValue != 0 else { return 0 }
        return Double(value) / Double(maxValue)
    }

    static func remapInt01(_ value: Int, bitDepthMax: Int) -> Double {
        remapInt01(value, maxValue: bitDepthMax)
    }

    static func lerp(_ beginning: Double, _ end: Double, t value01: Double) -> Double {
        precondition((0...1).contains(value01), "Lerp parameter must be within [0,1]")
        return beginning + (end - beginning) * value01
    }

    static func smoothstep(_ beginning: Double, _ end: Double, percentage: Double) -> Double {
        precondition((0...1).contains(percentage), "Percentage out of bounds [0,1]")
        let value = remapNoError(percentage,
                                 inputLow: 0,
                                 inputHigh: 1,
                                 outputLow: beginning,
                                 outputHigh: end)
        return value * value * (3 - 2 * value)
    }

    static func smootherstep(_ beginning: Double, _ end: Double, percentage: Double) -> Double {
        precondition((0...1).contains(percentage), "Percentage out of bounds [0,1]")
        let value = remapNoError(percentage,
                                 inputLow: 0,
                                 inputHigh: 1,
                                 outputLow: beginning,
                                 outputHigh: end)
        return value * value * value * (value * (value * 6 - 15) + 10)
    }

    static func distance(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Float {
        simd_distance(lhs, rhs)
    }

    static func distance(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        simd_distance(lhs, rhs)
    }

    static func roundToNearest(_ value: Double, nearest: Double) -> Double {
        guard nearest != 0 else { return value }
        let multiplier = floor(value / nearest)
        return multiplier * nearest
    }

    static func maxInteger(bitDepth: Int) -> Int {
        guard bitDepth > 0 else { return 0 }
        return Int(pow(2.0, Double(bitDepth)) - 1.0)
    }

    static func indicesDoubleArray(start: Double,
                                   end: Double,
                                   count: Int) -> [Double] {
        guard count > 0 else { return [] }
        if count == 1 { return [start] }
        let step = remapNoError(1,
                                inputLow: 0,
                                inputHigh: Double(count - 1),
                                outputLow: start,
                                outputHigh: end)
        return (0..<count).map { index in
            let raw = Double(index) * step
            return clampUpperBound(raw, upperBound: end)
        }
    }

    static func indicesIntegerArray(start: Int,
                                    end: Int,
                                    count: Int) -> [Int] {
        guard count > 0 else { return [] }
        if count == 1 { return [start] }
        let step = remapNoError(1,
                                inputLow: 0,
                                inputHigh: Double(count - 1),
                                outputLow: Double(start),
                                outputHigh: Double(end))
        return (0..<count).map { index in
            Int(round(Double(index) * step))
        }
    }

    static func indicesIntegerArrayLegacy(start: Int,
                                          end: Int,
                                          count: Int) -> [Int] {
        guard count > 0 else { return [] }
        var indices = indicesIntegerArray(start: start, end: end + 1, count: count)
        if !indices.isEmpty {
            indices[indices.count - 1] = end
        }
        return indices
    }

    static func outOfBounds(_ value: Double,
                            lowerBound: Double,
                            upperBound: Double,
                            inclusive: Bool) -> Bool {
        inclusive ? (value < lowerBound || value > upperBound)
                   : (value <= lowerBound || value >= upperBound)
    }
}

enum LUTStringHelper {
    static func arrayRemovingEmptyElements(_ array: [String]) -> [String] {
        array.filter { !$0.isEmpty }
    }

    static func componentsSeparatedByWhitespace(_ string: String) -> [String] {
        let components = string.components(separatedBy: .whitespaces)
        return arrayRemovingEmptyElements(components)
    }

    static func componentsSeparatedByNewlines(_ string: String) -> [String] {
        let components = string.components(separatedBy: .newlines)
        return arrayRemovingEmptyElements(components)
    }

    static func componentsSeparatedByWhitespaceAndNewlines(_ string: String) -> [String] {
        let components = string.components(separatedBy: .whitespacesAndNewlines)
        return arrayRemovingEmptyElements(components)
    }

    static func substring(between first: String,
                          and second: String,
                          in origin: String) -> String? {
        guard let range1 = origin.range(of: first),
              let range2 = origin.range(of: second, options: [], range: range1.upperBound..<origin.endIndex) else {
            return nil
        }
        return String(origin[range1.upperBound..<range2.lowerBound])
    }

    static func stringIsValidNumber(_ string: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "e-.0123456789 ")
        return string.rangeOfCharacter(from: allowed.inverted) == nil
    }

    static func findFirstLUTLine(in lines: [String],
                                 separator: String,
                                 valueCount: Int,
                                 startLine: Int = 0) -> Int? {
        guard startLine < lines.count else { return nil }
        for index in startLine..<lines.count {
            let parts = arrayRemovingEmptyElements(lines[index].components(separatedBy: separator))
            if parts.count == valueCount && parts.allSatisfy(stringIsValidNumber) {
                return index
            }
        }
        return nil
    }

    static func findFirstLUTLineWithWhitespaceSeparators(in lines: [String],
                                                         valueCount: Int,
                                                         startLine: Int = 0) -> Int? {
        guard startLine < lines.count else { return nil }
        for index in startLine..<lines.count {
            let parts = componentsSeparatedByWhitespace(lines[index])
            if parts.count == valueCount && parts.allSatisfy(stringIsValidNumber) {
                return index
            }
        }
        return nil
    }
}

enum LUTColorHelper {
    static func color(from hexString: String) -> SystemColor? {
        let cleaned = hexString.replacingOccurrences(of: "#", with: "")
        guard let value = UInt64(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0

        #if canImport(UIKit)
        return SystemColor(red: red, green: green, blue: blue, alpha: 1)
        #elseif canImport(AppKit)
        return SystemColor(deviceRed: red, green: green, blue: blue, alpha: 1)
        #else
        return nil
        #endif
    }
}