import Foundation

enum LUTFormatterILUTError: Error, Equatable, LocalizedError {
    case invalidComponentCount(line: Int)
    case nonNumericComponent(line: Int)
    case unsupportedLUT

    var errorDescription: String? {
        switch self {
        case .invalidComponentCount(let line):
            return "Line \(line) does not contain the expected number of components."
        case .nonNumericComponent(let line):
            return "Line \(line) contains a non-numeric value."
        case .unsupportedLUT:
            return "The provided LUT is not compatible with the ILUT format."
        }
    }
}

enum LUTFormatterILUT {
    static let formatterIdentifier = "ilut"
    private static let bitDepth = 14
    private static let requiredSampleCount = 1 << bitDepth

    static func read(string: String) throws -> LUT1D {
        let rawLines = string.components(separatedBy: .newlines)
        var red: [Double] = []
        var green: [Double] = []
        var blue: [Double] = []
        red.reserveCapacity(rawLines.count)
        green.reserveCapacity(rawLines.count)
        blue.reserveCapacity(rawLines.count)

        let maxInteger = LUTMath.maxInteger(bitDepth: bitDepth)

        for (index, rawLine) in rawLines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let components = trimmed.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard components.count >= 3 else {
                throw LUTFormatterILUTError.invalidComponentCount(line: index + 1)
            }

            guard let r = Int(components[0]),
                  let g = Int(components[1]),
                  let b = Int(components[2]) else {
                throw LUTFormatterILUTError.nonNumericComponent(line: index + 1)
            }

            red.append(LUTMath.remapInt01(r, maxValue: maxInteger))
            green.append(LUTMath.remapInt01(g, maxValue: maxInteger))
            blue.append(LUTMath.remapInt01(b, maxValue: maxInteger))
        }

        guard !red.isEmpty else {
            throw LUTFormatterILUTError.invalidComponentCount(line: 0)
        }

        var lut = LUT1D(redCurve: red,
                        greenCurve: green,
                        blueCurve: blue,
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        lut.passthroughFileOptions = [formatterIdentifier: [:]]
        return lut
    }

    static func read(url: URL) throws -> LUT1D {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func write(_ lut: LUT1D) throws -> String {
        let workingLUT: LUT1D
        if lut.size == requiredSampleCount {
            workingLUT = lut
        } else if lut.size == 0 {
            throw LUTFormatterILUTError.unsupportedLUT
        } else {
            workingLUT = lut.resized(to: requiredSampleCount)
        }

        let maxInteger = Double(LUTMath.maxInteger(bitDepth: bitDepth))
        var lines: [String] = []
        lines.reserveCapacity(requiredSampleCount)

        for index in 0..<requiredSampleCount {
            let red = Int((LUTMath.clamp01(workingLUT.valueAtR(index)) * maxInteger).rounded(.down))
            let green = Int((LUTMath.clamp01(workingLUT.valueAtG(index)) * maxInteger).rounded(.down))
            let blue = Int((LUTMath.clamp01(workingLUT.valueAtB(index)) * maxInteger).rounded(.down))
            lines.append("\(red),\(green),\(blue),0")
        }

        return lines.joined(separator: "\n")
    }
}
