import Foundation

enum LUTFormatterOLUTError: Error, Equatable, LocalizedError {
    case invalidComponentCount(line: Int)
    case invalidNumber(line: Int, column: Int)
    case emptyPayload

    var errorDescription: String? {
        switch self {
        case .invalidComponentCount(let line):
            return "Blackmagic Design 1D LUT line \(line) does not contain three numeric components."
        case .invalidNumber(let line, let column):
            return "Blackmagic Design 1D LUT encountered a non-numeric value at line \(line), column \(column)."
        case .emptyPayload:
            return "Blackmagic Design 1D LUT payload is empty."
        }
    }
}

enum LUTFormatterOLUT {
    static let formatterIdentifier = "olut"

    struct Options {
        var lutSize: Int

        init(lutSize: Int = 4096) {
            self.lutSize = lutSize
        }
    }

    static func read(url: URL) throws -> LUT1D {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func read(data: Data) throws -> LUT1D {
        guard let contents = String(data: data, encoding: .utf8) else {
            throw LUTFormatterOLUTError.emptyPayload
        }
        return try read(string: contents)
    }

    static func read(string: String) throws -> LUT1D {
        let rawLines = string.components(separatedBy: .newlines)
        var red: [Double] = []
        var green: [Double] = []
        var blue: [Double] = []
        red.reserveCapacity(rawLines.count)
        green.reserveCapacity(rawLines.count)
        blue.reserveCapacity(rawLines.count)

        let maxValue = LUTMath.maxInteger(bitDepth: 12)

        for (index, rawLine) in rawLines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let components = trimmed
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard components.count >= 3 else {
                throw LUTFormatterOLUTError.invalidComponentCount(line: index + 1)
            }

            func sample(at column: Int) throws -> Double {
                guard let value = Int(components[column]) else {
                    throw LUTFormatterOLUTError.invalidNumber(line: index + 1, column: column + 1)
                }
                return LUTMath.remapInt01(value, maxValue: maxValue)
            }

            red.append(try sample(at: 0))
            green.append(try sample(at: 1))
            blue.append(try sample(at: 2))
        }

        guard !red.isEmpty else { throw LUTFormatterOLUTError.emptyPayload }

        var lut = LUT1D(redCurve: red,
                        greenCurve: green,
                        blueCurve: blue,
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        lut.passthroughFileOptions = passthroughOptions(lutSize: lut.size)
        return lut
    }

    static func write(_ lut: LUT1D, options: Options? = nil) throws -> String {
        let resolvedOptions = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? Options(lutSize: lut.size)

        let workingLUT: LUT1D
        if lut.size == resolvedOptions.lutSize {
            workingLUT = lut
        } else {
            workingLUT = lut.resized(to: resolvedOptions.lutSize)
        }

        let maxOutput = Double(LUTMath.maxInteger(bitDepth: 12))

        func quantized(_ value: Double) -> Int {
            let clamped = LUTMath.clamp01(value)
            return Int(clamped * maxOutput)
        }

        var rows: [String] = []
        rows.reserveCapacity(workingLUT.size)

        for index in 0..<workingLUT.size {
            let r = quantized(workingLUT.valueAtR(index))
            let g = quantized(workingLUT.valueAtG(index))
            let b = quantized(workingLUT.valueAtB(index))
            rows.append("\(r),\(g),\(b),\(r),\(g),\(b)")
        }

        return rows.joined(separator: "\n")
    }

    private static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else { return nil }
        if let lutSize = formatterOptions["lutSize"] as? Int { return Options(lutSize: lutSize) }
        if let number = formatterOptions["lutSize"] as? NSNumber { return Options(lutSize: number.intValue) }
        return nil
    }

    private static func passthroughOptions(lutSize: Int) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": "OLUT",
                               "lutSize": lutSize]]
    }
}
