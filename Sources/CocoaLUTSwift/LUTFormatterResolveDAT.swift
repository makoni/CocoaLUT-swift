import Foundation

enum LUTFormatterResolveDATErrors: Error, Equatable, LocalizedError {
    case missingDataSection
    case invalidSizeDeclaration
    case invalidNumber(line: Int)
    case incompleteData(expected: Int, found: Int)

    var errorDescription: String? {
        switch self {
        case .missingDataSection:
            return "Resolve DAT file did not contain any LUT data section."
        case .invalidSizeDeclaration:
            return "Resolve DAT file declared an invalid LUT size."
        case .invalidNumber(let line):
            return "Encountered non-numeric data while parsing Resolve DAT at line \(line)."
        case .incompleteData(let expected, let found):
            return "Resolve DAT file contained \(found) entries but \(expected) were expected."
        }
    }
}

enum LUTFormatterResolveDAT {
    static let formatterIdentifier = "resolveDAT"

    struct Options {
        var fileTypeVariant: String

        init(fileTypeVariant: String = "Resolve") {
            self.fileTypeVariant = fileTypeVariant
        }
    }

    static func read(url: URL) throws -> LUT3D {
        let string = try String(contentsOf: url, encoding: .utf8)
        return try read(string: string)
    }

    static func read(string: String) throws -> LUT3D {
        try read(string: string, variant: Options().fileTypeVariant)
    }

    static func read(string: String, variant: String) throws -> LUT3D {
        let lines = string.components(separatedBy: .newlines)
        guard let dataStart = LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines,
                                                                                       valueCount: 3,
                                                                                       startLine: 0) else {
            throw LUTFormatterResolveDATErrors.missingDataSection
        }

        let headerLines = Array(lines[..<dataStart])
        let size = try resolveSize(from: headerLines)
        let expectedEntries = size * size * size
        var samples: [LUTColor] = []
        samples.reserveCapacity(expectedEntries)

        for (offset, rawLine) in lines[dataStart...].enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.hasPrefix("#") == false else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3 else { continue }
            guard components.allSatisfy(LUTStringHelper.stringIsValidNumber) else {
                throw LUTFormatterResolveDATErrors.invalidNumber(line: dataStart + offset + 1)
            }
            guard let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else {
                throw LUTFormatterResolveDATErrors.invalidNumber(line: dataStart + offset + 1)
            }

            samples.append(LUTColor.color(red: r, green: g, blue: b))
            if samples.count == expectedEntries { break }
        }

        guard samples.count == expectedEntries else {
            throw LUTFormatterResolveDATErrors.incompleteData(expected: expectedEntries, found: samples.count)
        }

        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        for (index, color) in samples.enumerated() {
            let redIndex = index / (size * size)
            let greenIndex = (index % (size * size)) / size
            let blueIndex = index % size
            lut.setColor(color, r: redIndex, g: greenIndex, b: blueIndex)
        }

        lut.passthroughFileOptions = passthroughOptions(variant: variant)
        return lut
    }

    static func write(_ lut: LUT3D, options: Options? = nil) throws -> String {
        let _ = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? Options()

        var rows: [String] = []
        rows.reserveCapacity(lut.size * lut.size * lut.size)
        let locale = Locale(identifier: "en_US_POSIX")

        for index in 0..<(lut.size * lut.size * lut.size) {
            let redIndex = index / (lut.size * lut.size)
            let greenIndex = (index % (lut.size * lut.size)) / lut.size
            let blueIndex = index % lut.size
            let color = lut.colorAt(r: redIndex, g: greenIndex, b: blueIndex)
            let row = String(format: "%.6f %.6f %.6f",
                             locale: locale,
                             color.red,
                             color.green,
                             color.blue)
            rows.append(row)
        }

        let dataBlock = rows.joined(separator: "\n")
        let header: String
        if lut.size == 33 {
            header = ""
        } else {
            header = "3DLUTSIZE \(lut.size)\n\n"
        }

        return header + dataBlock
    }

    private static func resolveSize(from headerLines: [String]) throws -> Int {
        for rawLine in headerLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.hasPrefix("#") == false else { continue }
            let upper = trimmed.uppercased()
            if upper.hasPrefix("3DLUTSIZE") {
                let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
                guard components.count == 2, let size = Int(components[1]), size > 0 else {
                    throw LUTFormatterResolveDATErrors.invalidSizeDeclaration
                }
                return size
            }
        }
        return 33
    }

    private static func passthroughOptions(variant: String) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": variant]]
    }

    private static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else { return nil }
        guard let variant = formatterOptions["fileTypeVariant"] as? String else { return nil }
        return Options(fileTypeVariant: variant)
    }
}
