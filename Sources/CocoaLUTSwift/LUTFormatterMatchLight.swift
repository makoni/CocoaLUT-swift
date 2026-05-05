import Foundation

enum LUTFormatterMatchLightError: Error, Equatable, LocalizedError {
    case missingLUTData
    case missingSizes
    case invalidNumber(line: Int, column: Int)
    case incomplete1D(expected: Int, actual: Int)
    case incomplete3D(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .missingLUTData:
            return "Could not locate MatchLight LUT payload."
        case .missingSizes:
            return "MatchLight header did not declare LUT sizes."
        case .invalidNumber(let line, let column):
            return "Encountered a non-numeric value while parsing MatchLight LUT at line \(line), column \(column)."
        case .incomplete1D(let expected, let actual):
            return "MatchLight 1D section contained \(actual) entries but \(expected) were required."
        case .incomplete3D(let expected, let actual):
            return "MatchLight 3D section contained \(actual) entries but \(expected) were required."
        }
    }
}

enum LUTFormatterMatchLight {
    static let formatterIdentifier = "matchLight"

    static func read(url: URL) throws -> LUT3D {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func read(string: String) throws -> LUT3D {
        let rawLines = string.components(separatedBy: .newlines)
        let lines = rawLines.map { $0.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let lut1DStart = LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines,
                                                                                         valueCount: 3,
                                                                                         startLine: 0) else {
            throw LUTFormatterMatchLightError.missingLUTData
        }

        var lut1DSize: Int?
        var lut3DSize: Int?
        var lut3DStart: Int?

        for (index, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
            if line.contains("lutS"), components.count > 2, let value = Int(components[2]) {
                lut1DSize = value
            } else if line.contains("cubeS"), components.count > 2, let value = Int(components[2]) {
                lut3DSize = value
            } else if line.contains("# CUBE") {
                lut3DStart = LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines,
                                                                                       valueCount: 3,
                                                                                       startLine: index)
                break
            }
        }

        guard let size1D = lut1DSize,
              let size3D = lut3DSize,
              let cubeStart = lut3DStart else {
            throw LUTFormatterMatchLightError.missingSizes
        }

        let denominator = max(size3D - 1, 1)
        let lut1DEnd = min(lines.count, lut1DStart + size1D)
        let lut1DLines = Array(lines[lut1DStart..<lut1DEnd])
        var preLUT = LUT1D(redCurve: Array(repeating: 0, count: size1D),
                            greenCurve: Array(repeating: 0, count: size1D),
                            blueCurve: Array(repeating: 0, count: size1D),
                            inputLowerBound: 0,
                            inputUpperBound: 1)
        var current1D = 0

        for (offset, line) in lut1DLines.enumerated() {
            guard !line.isEmpty else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
            guard components.count == 3 else { continue }
            let values = try components.enumerated().map { column, token -> Double in
                guard let number = Double(token) else {
                    throw LUTFormatterMatchLightError.invalidNumber(line: lut1DStart + offset + 1, column: column + 1)
                }
                return number / Double(denominator)
            }
            let color = LUTColor.color(red: values[0], green: values[1], blue: values[2])
            preLUT.setColor(color, index: current1D)
            current1D += 1
        }

        guard current1D == size1D else {
            throw LUTFormatterMatchLightError.incomplete1D(expected: size1D, actual: current1D)
        }

        let expected3DEntries = size3D * size3D * size3D
        let cubeEnd = min(lines.count, cubeStart + expected3DEntries)
        let cubeLines = Array(lines[cubeStart..<cubeEnd])
        var cube = LUT3D.identity(size: size3D, inputLowerBound: 0, inputUpperBound: 1)
        var current3D = 0

        for (offset, line) in cubeLines.enumerated() {
            guard !line.isEmpty else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
            guard components.count == 3 else { continue }
            let values = try components.enumerated().map { column, token -> Double in
                guard let number = Double(token) else {
                    throw LUTFormatterMatchLightError.invalidNumber(line: cubeStart + offset + 1, column: column + 1)
                }
                return number
            }
            let color = LUTColor.color(red: values[0], green: values[1], blue: values[2])
            let rIndex = current3D / (size3D * size3D)
            let gIndex = (current3D % (size3D * size3D)) / size3D
            let bIndex = current3D % size3D
            cube.setColor(color, r: rIndex, g: gIndex, b: bIndex)
            current3D += 1
        }

        guard current3D == expected3DEntries else {
            throw LUTFormatterMatchLightError.incomplete3D(expected: expected3DEntries, actual: current3D)
        }

        var combined = LUTFormatterNucodaCMS.combine(preLUT: preLUT, cube: cube)
        combined.passthroughFileOptions = passthroughOptions(lut1DSize: size1D, lut3DSize: size3D)
        return combined
    }

    private static func passthroughOptions(lut1DSize: Int, lut3DSize: Int) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": "MatchLight",
                               "lut1DSize": lut1DSize,
                               "lut3DSize": lut3DSize]]
    }
}
