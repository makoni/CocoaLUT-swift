import Foundation

enum LUTFormatterDiscreet1DError: Error, Equatable, LocalizedError {
    case missingScale
    case missingSize
    case incompleteData
    case invalidNumber(line: Int)

    var errorDescription: String? {
        switch self {
        case .missingScale:
            return "Discreet LUT header did not declare an output scale."
        case .missingSize:
            return "Discreet LUT header did not declare a LUT size."
        case .incompleteData:
            return "Discreet LUT data section is incomplete."
        case .invalidNumber(let line):
            return "Encountered a non-numeric value while parsing Discreet LUT at line \(line)."
        }
    }
}

enum LUTFormatterDiscreet1DLUT {
    static let formatterIdentifier = "discreet"

    struct Options {
        var integerMaxOutput: Int

        init(integerMaxOutput: Int) {
            self.integerMaxOutput = integerMaxOutput
        }
    }

    static func read(url: URL) throws -> LUT1D {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func read(string: String) throws -> LUT1D {
        let lines = string.components(separatedBy: .newlines)
        guard let lutStart = LUTStringHelper.findFirstLUTLine(in: lines, separator: "", valueCount: 1, startLine: 0) else {
            throw LUTFormatterDiscreet1DError.incompleteData
        }

        let headerLines = Array(lines[..<lutStart])
        var integerMaxOutput: Int?
        var lutSize: Int?

        for rawLine in headerLines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.contains("Scale") {
                let components = line.components(separatedBy: ":")
                if let value = components.last?.trimmingCharacters(in: .whitespaces),
                   let intValue = Int(value) {
                    integerMaxOutput = intValue
                }
            }
            if line.hasPrefix("LUT") {
                let components = line.components(separatedBy: .whitespaces)
                if components.count >= 3, let value = Int(components[2]) {
                    lutSize = value
                }
            }
        }

        guard let maxOutput = integerMaxOutput else { throw LUTFormatterDiscreet1DError.missingScale }
        guard let size = lutSize, size > 0 else { throw LUTFormatterDiscreet1DError.missingSize }

        var trimmedValues: [String] = []
        trimmedValues.reserveCapacity(size * 3)
        for (index, rawLine) in lines.enumerated() {
            guard index >= lutStart else { continue }
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("#") || trimmed.contains("LUT") { continue }
            if trimmed.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) == nil { continue }
            if !trimmed.allSatisfy({ $0.isNumber || $0 == "-" }) {
                if Int(trimmed) == nil {
                    throw LUTFormatterDiscreet1DError.invalidNumber(line: index + 1)
                }
            }
            if let _ = Int(trimmed) {
                trimmedValues.append(trimmed)
            }
        }

        guard trimmedValues.count >= size * 3 else { throw LUTFormatterDiscreet1DError.incompleteData }

        func curve(range: Range<Int>) -> [Double] {
            range.map { index in
                let value = Int(trimmedValues[index]) ?? 0
                return LUTMath.remapInt01(value, maxValue: maxOutput)
            }
        }

        let redCurve = curve(range: 0..<size)
        let greenCurve = curve(range: size..<(2 * size))
        let blueCurve = curve(range: (2 * size)..<(3 * size))

        var lut = LUT1D(redCurve: redCurve,
                        greenCurve: greenCurve,
                        blueCurve: blueCurve,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let metadata = LUTMetadataFormatter.metadataAndDescription(from: headerLines)
        lut.metadata = metadata.metadata
        lut.descriptionText = metadata.description
        lut.passthroughFileOptions = passthroughOptions(integerMaxOutput: maxOutput, lutSize: size)
        return lut
    }

    static func write(_ lut: LUT1D, options: Options? = nil) throws -> String {
        let resolvedOptions = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? Options(integerMaxOutput: LUTMath.maxInteger(bitDepth: 12))

        let header = headerString(lutSize: lut.size, integerMaxOutput: resolvedOptions.integerMaxOutput)

        let redLines = (0..<lut.size).map { index -> String in
            formatSample(lut.valueAtR(index), maxOutput: resolvedOptions.integerMaxOutput)
        }
        let greenLines = (0..<lut.size).map { index -> String in
            formatSample(lut.valueAtG(index), maxOutput: resolvedOptions.integerMaxOutput)
        }
        let blueLines = (0..<lut.size).map { index -> String in
            formatSample(lut.valueAtB(index), maxOutput: resolvedOptions.integerMaxOutput)
        }

        return ([header] + redLines + greenLines + blueLines).joined(separator: "\n")
    }

    private static func headerString(lutSize: Int, integerMaxOutput: Int) -> String {
        "#\n# Discreet LUT file\n#\tChannels: 3\n# Input Samples: \(lutSize)\n# Ouput Scale: \(integerMaxOutput)\n#\n# Exported from CocoaLUT\n#\nLUT: 3 \(lutSize)"
    }

    private static func formatSample(_ value: Double, maxOutput: Int) -> String {
        let scaled = LUTMath.clamp01(value) * Double(maxOutput)
        return String(Int(scaled.rounded(.down)))
    }

    private static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else { return nil }
        if let integerMaxOutput = formatterOptions["integerMaxOutput"] as? Int {
            return Options(integerMaxOutput: integerMaxOutput)
        }
        if let number = formatterOptions["integerMaxOutput"] as? NSNumber {
            return Options(integerMaxOutput: number.intValue)
        }
        return nil
    }

    private static func passthroughOptions(integerMaxOutput: Int, lutSize: Int) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": "Discreet",
                               "integerMaxOutput": integerMaxOutput,
                               "lutSize": lutSize]]
    }
}
