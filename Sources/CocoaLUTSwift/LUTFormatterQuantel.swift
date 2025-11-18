import Foundation
import simd

enum LUTFormatterQuantelError: Error, Equatable, LocalizedError {
    case missingMaxOutput
    case missingSize
    case invalidNumber(line: Int)
    case incompleteData

    var errorDescription: String? {
        switch self {
        case .missingMaxOutput:
            return "Quantel LUT header did not declare a maximum output value."
        case .missingSize:
            return "Quantel LUT header did not declare a vertex count."
        case .invalidNumber(let line):
            return "Encountered non-numeric data while parsing Quantel LUT at line \(line)."
        case .incompleteData:
            return "Quantel LUT contained fewer data rows than expected."
        }
    }
}

enum LUTFormatterQuantel {
    static let formatterIdentifier = "quantel"

    struct Options {
        var integerMaxOutput: Int
        var lutSize: Int
    }

    static func read(url: URL) throws -> LUT3D {
        let string = try String(contentsOf: url, encoding: .utf8)
        return try read(string: string)
    }

    static func read(string: String) throws -> LUT3D {
        let lines = string.components(separatedBy: .newlines)
        guard let dataStart = LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines,
                                                                                       valueCount: 3,
                                                                                       startLine: 0) else {
            throw LUTFormatterQuantelError.incompleteData
        }

        let headerLines = Array(lines[..<dataStart])
        var integerMaxOutput: Int?
        var lutSize: Int?

        for rawLine in headerLines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("max value") {
                let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
                if let value = components.last, let intValue = Int(value) {
                    integerMaxOutput = intValue
                }
            }
            if line.hasPrefix("vertices") {
                let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
                if components.count >= 2, let value = Int(components[1]) {
                    lutSize = value
                }
            }
        }

        guard let maxOutput = integerMaxOutput else { throw LUTFormatterQuantelError.missingMaxOutput }
        guard let size = lutSize, size > 0 else { throw LUTFormatterQuantelError.missingSize }

        let expectedEntries = size * size * size
        var values: [SIMD3<Double>] = []
        values.reserveCapacity(expectedEntries)

        for (offset, rawLine) in lines[dataStart...].enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3 else { continue }
            guard let r = Int(components[0]),
                  let g = Int(components[1]),
                  let b = Int(components[2]) else {
                throw LUTFormatterQuantelError.invalidNumber(line: dataStart + offset + 1)
            }
            values.append(SIMD3(Double(r), Double(g), Double(b)))
            if values.count == expectedEntries { break }
        }

        guard values.count == expectedEntries else { throw LUTFormatterQuantelError.incompleteData }

        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for (index, sample) in values.enumerated() {
            let redIndex = index / (size * size)
            let greenIndex = (index % (size * size)) / size
            let blueIndex = index % size
            let color = LUTColor.color(red: sample.x / Double(maxOutput),
                                       green: sample.y / Double(maxOutput),
                                       blue: sample.z / Double(maxOutput))
            lut.setColor(color, r: redIndex, g: greenIndex, b: blueIndex)
        }

        lut.passthroughFileOptions = passthroughOptions(integerMaxOutput: maxOutput, lutSize: size)
        return lut
    }

    static func write(_ lut: LUT3D, options: Options? = nil) throws -> String {
        let resolved = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? Options(integerMaxOutput: LUTMath.maxInteger(bitDepth: 16), lutSize: lut.size)

        guard lut.size == resolved.lutSize else {
            throw LUTFormatterQuantelError.incompleteData
        }

        var rows: [String] = []
        rows.reserveCapacity(lut.size * lut.size * lut.size)
        for index in 0..<(lut.size * lut.size * lut.size) {
            let redIndex = index / (lut.size * lut.size)
            let greenIndex = (index % (lut.size * lut.size)) / lut.size
            let blueIndex = index % lut.size
            let color = lut.colorAt(r: redIndex, g: greenIndex, b: blueIndex)
            let r = quantize(color.red, maxOutput: resolved.integerMaxOutput)
            let g = quantize(color.green, maxOutput: resolved.integerMaxOutput)
            let b = quantize(color.blue, maxOutput: resolved.integerMaxOutput)
            rows.append("\(r) \(g) \(b)")
        }

        let header = """
        max value \(resolved.integerMaxOutput)
        vertices \(resolved.lutSize)
        blue is fastest changing
        red is slowest changing

        cube data
        R G B
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        return ([header] + rows).joined(separator: "\n")
    }

    private static func quantize(_ value: Double, maxOutput: Int) -> Int {
        let clamped = LUTMath.clamp01(value)
        return Int((clamped * Double(maxOutput)).rounded(.down))
    }

    private static func passthroughOptions(integerMaxOutput: Int, lutSize: Int) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": "Quantel",
                               "integerMaxOutput": integerMaxOutput,
                               "lutSize": lutSize]]
    }

    private static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else { return nil }
        guard let integerMaxOutput = (formatterOptions["integerMaxOutput"] as? NSNumber)?.intValue ?? formatterOptions["integerMaxOutput"] as? Int,
              let lutSize = (formatterOptions["lutSize"] as? NSNumber)?.intValue ?? formatterOptions["lutSize"] as? Int else {
            return nil
        }
        return Options(integerMaxOutput: integerMaxOutput, lutSize: lutSize)
    }
}
