import Foundation

enum LUTFormatterNucodaCMSError: Error, Equatable, LocalizedError {
    case invalidHeader(String)
    case invalidNumber(line: Int)
    case incompleteData(expected: Int, actual: Int)
    case unsupportedConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .invalidHeader(let message):
            return "Nucoda CMS header error: \(message)."
        case .invalidNumber(let line):
            return "Encountered a non-numeric value while parsing Nucoda CMS data at line \(line)."
        case .incompleteData(let expected, let actual):
            return "Nucoda CMS data contained \(actual) rows, but \(expected) rows were required."
        case .unsupportedConfiguration(let message):
            return "Unsupported Nucoda CMS configuration: \(message)."
        }
    }
}

enum LUTFormatterNucodaCMSResult {
    case lut1D(LUT1D)
    case lut3D(LUT3D)

    var lut1D: LUT1D? {
        if case let .lut1D(value) = self { return value }
        return nil
    }

    var lut3D: LUT3D? {
        if case let .lut3D(value) = self { return value }
        return nil
    }
}

enum LUTFormatterNucodaCMS {
    static let formatterIdentifier = "nucoda"

    enum Variant: String {
        case v1 = "Nucoda v1"
        case v2 = "Nucoda v2"
        case v3 = "Nucoda v3"

        init?(versionNumber: Int) {
            switch versionNumber {
            case 1: self = .v1
            case 2: self = .v2
            case 3: self = .v3
            default: return nil
            }
        }

        var versionNumber: Int {
            switch self {
            case .v1: return 1
            case .v2: return 2
            case .v3: return 3
            }
        }
    }

    enum LUTType: String {
        case noPreLUT = "No Pre-LUT"
        case preLUTAndLUT = "Pre-LUT and LUT"
    }

    struct Options {
        var variant: Variant

        static let `default` = Options(variant: .v3)
    }

    // MARK: Reading

    static func read(url: URL) throws -> LUTFormatterNucodaCMSResult {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func read(string: String) throws -> LUTFormatterNucodaCMSResult {
        var rawLines = string.components(separatedBy: .newlines)
        rawLines = rawLines.map { $0.replacingOccurrences(of: "\r", with: "") }
        let lines = LUTStringHelper.arrayRemovingEmptyElements(rawLines)

        guard let dataStart = LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines,
                                                                                       valueCount: 3,
                                                                                       startLine: 0) else {
            throw LUTFormatterNucodaCMSError.invalidHeader("Unable to locate LUT data payload")
        }

        let headerLines = Array(lines[..<dataStart])
        let payloadLines = Array(lines[dataStart..<lines.count])

        var header = try parseHeader(from: headerLines)
        let metadata = LUTMetadataFormatter.metadataAndDescription(from: headerLines)
        header.metadata = metadata.metadata
        header.description = metadata.description

        var cursor = 0
        var lut1DColors: [LUTColor] = []
        var lut3DColors: [LUTColor] = []

        if header.use1D, let size1D = header.size1D {
            guard cursor + size1D <= payloadLines.count else {
                throw LUTFormatterNucodaCMSError.incompleteData(expected: size1D, actual: payloadLines.count - cursor)
            }
            let slice = Array(payloadLines[cursor..<(cursor + size1D)])
            lut1DColors = try parse1DLines(slice,
                                           expectedSize: size1D,
                                           startLine: dataStart + cursor)
            cursor += size1D
        }

        if header.use3D, let size3D = header.size3D {
            let expected = size3D * size3D * size3D
            guard cursor + expected <= payloadLines.count else {
                throw LUTFormatterNucodaCMSError.incompleteData(expected: expected, actual: max(payloadLines.count - cursor, 0))
            }
            let slice = Array(payloadLines[cursor..<(cursor + expected)])
            lut3DColors = try parse3DLines(slice,
                                           size: size3D,
                                           startLine: dataStart + cursor)
        }

        guard header.use1D || header.use3D else {
            throw LUTFormatterNucodaCMSError.unsupportedConfiguration("No 1D or 3D data sections present")
        }

        let variant = header.variant
        let lutType: LUTType = header.use1D && header.use3D ? .preLUTAndLUT : .noPreLUT

        if header.use1D && header.use3D {
            let bounds1D = try header.input1DBounds(for: variant)
            let lut1D = try buildLUT1D(from: lut1DColors,
                                       size: header.size1D!,
                                       bounds: bounds1D,
                                       title: header.title,
                                       metadata: header.metadata,
                                       description: header.description)
            var preprocessed1D = lut1D
            if variant == .v1 {
                preprocessed1D = normalizeLegacyPreLUT(preprocessed1D, scale: Double(header.size3D!))
            }

            let bounds3D = try header.input3DBounds(for: variant)
            let lut3D = try buildLUT3D(from: lut3DColors,
                                       size: header.size3D!,
                                       bounds: bounds3D,
                                       title: header.title,
                                       metadata: header.metadata,
                                       description: header.description)
            let combined = combine(preLUT: preprocessed1D, cube: lut3D)
            var output = combined
            output.title = header.title
            output.metadata = header.metadata
            output.descriptionText = header.description
            output.passthroughFileOptions = passthroughOptions(variant: variant,
                                                               lutType: lutType)
            return .lut3D(output)
        } else if header.use1D {
            let bounds1D = try header.input1DBounds(for: variant)
            var lut1D = try buildLUT1D(from: lut1DColors,
                                       size: header.size1D!,
                                       bounds: bounds1D,
                                       title: header.title,
                                       metadata: header.metadata,
                                       description: header.description)
            lut1D.passthroughFileOptions = passthroughOptions(variant: variant,
                                                               lutType: lutType)
            return .lut1D(lut1D)
        } else {
            let bounds3D = try header.input3DBounds(for: variant)
            var lut3D = try buildLUT3D(from: lut3DColors,
                                       size: header.size3D!,
                                       bounds: bounds3D,
                                       title: header.title,
                                       metadata: header.metadata,
                                       description: header.description)
            lut3D.passthroughFileOptions = passthroughOptions(variant: variant,
                                                               lutType: lutType)
            return .lut3D(lut3D)
        }
    }

    // MARK: Writing

    static func write(_ result: LUTFormatterNucodaCMSResult,
                      options: Options? = nil) throws -> String {
        switch result {
        case .lut1D(let lut):
            let resolvedOptions = options
                ?? optionsFromPassthrough(lut.passthroughFileOptions)
                ?? .default
            return write1D(lut, variant: resolvedOptions.variant)
        case .lut3D(let lut):
            let resolvedOptions = options
                ?? optionsFromPassthrough(lut.passthroughFileOptions)
                ?? .default
            return write3D(lut, variant: resolvedOptions.variant)
        }
    }

    static func combine(preLUT: LUT1D, cube: LUT3D) -> LUT3D {
        combineInternal(preLUT: preLUT, cube: cube)
    }
}

// MARK: - Parsing Helpers

private extension LUTFormatterNucodaCMS {
    struct ParsedHeader {
        var variant: Variant
        var title: String?
        var metadata: [String: Any] = [:]
        var description: String?
        var use1D = false
        var use3D = false
        var size1D: Int?
        var size3D: Int?
        var input1D: (Double, Double)?
        var input3D: (Double, Double)?

        func input1DBounds(for variant: Variant) throws -> (Double, Double) {
            switch variant {
            case .v1, .v2:
                if use1D { return (0, 1) }
            case .v3:
                if let input1D { return input1D }
                throw LUTFormatterNucodaCMSError.invalidHeader("Missing LUT_1D_INPUT_RANGE for version 3 file")
            }
            throw LUTFormatterNucodaCMSError.invalidHeader("Missing LUT_1D_SIZE declaration")
        }

        func input3DBounds(for variant: Variant) throws -> (Double, Double) {
            switch variant {
            case .v1, .v2:
                if use3D { return (0, 1) }
            case .v3:
                if let input3D { return input3D }
                throw LUTFormatterNucodaCMSError.invalidHeader("Missing LUT_3D_INPUT_RANGE for version 3 file")
            }
            throw LUTFormatterNucodaCMSError.invalidHeader("Missing LUT_3D_SIZE declaration")
        }
    }

    static func parseHeader(from lines: [String]) throws -> ParsedHeader {
        var variant: Variant?
        var title: String?
        var size1D: Int?
        var size3D: Int?
        var use1D = false
        var use3D = false
        var input1D: (Double, Double)?
        var input3D: (Double, Double)?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let uppercased = trimmed.uppercased()
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)

            if uppercased.hasPrefix("NUCODA_3D_CUBE") {
                guard components.count == 2, let versionValue = Int(components[1]),
                      let resolvedVariant = Variant(versionNumber: versionValue) else {
                    throw LUTFormatterNucodaCMSError.invalidHeader("NUCODA_3D_CUBE declaration is invalid")
                }
                if variant != nil {
                    throw LUTFormatterNucodaCMSError.invalidHeader("NUCODA_3D_CUBE declared multiple times")
                }
                variant = resolvedVariant
                continue
            }

            if uppercased.hasPrefix("LUT_3D_SIZE") {
                guard components.count == 2, let value = Int(components[1]) else {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_3D_SIZE declaration is invalid")
                }
                if size3D != nil {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_3D_SIZE declared multiple times")
                }
                size3D = value
                use3D = true
                continue
            }

            if uppercased.hasPrefix("LUT_1D_SIZE") {
                guard components.count == 2, let value = Int(components[1]) else {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_1D_SIZE declaration is invalid")
                }
                if size1D != nil {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_1D_SIZE declared multiple times")
                }
                size1D = value
                use1D = true
                continue
            }

            if uppercased.hasPrefix("LUT_3D_INPUT_RANGE") {
                guard components.count >= 3,
                      let lower = Double(components[components.count - 2]),
                      let upper = Double(components.last!) else {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_3D_INPUT_RANGE declaration is invalid")
                }
                if input3D != nil {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_3D_INPUT_RANGE declared multiple times")
                }
                input3D = (lower, upper)
                continue
            }

            if uppercased.hasPrefix("LUT_1D_INPUT_RANGE") {
                guard components.count >= 3,
                      let lower = Double(components[components.count - 2]),
                      let upper = Double(components.last!) else {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_1D_INPUT_RANGE declaration is invalid")
                }
                if input1D != nil {
                    throw LUTFormatterNucodaCMSError.invalidHeader("LUT_1D_INPUT_RANGE declared multiple times")
                }
                input1D = (lower, upper)
                continue
            }

            if uppercased.hasPrefix("TITLE") {
                if let extracted = LUTStringHelper.substring(between: "TITLE \"",
                                                              and: "\"",
                                                              in: trimmed) {
                    title = extracted
                }
            }
        }

        guard let resolvedVariant = variant else {
            throw LUTFormatterNucodaCMSError.invalidHeader("Missing NUCODA_3D_CUBE declaration")
        }

        if use1D && size1D == nil {
            throw LUTFormatterNucodaCMSError.invalidHeader("LUT_1D_SIZE is required when LUT_1D data is present")
        }

        if use3D && size3D == nil {
            throw LUTFormatterNucodaCMSError.invalidHeader("LUT_3D_SIZE is required when LUT_3D data is present")
        }

        return ParsedHeader(variant: resolvedVariant,
                            title: title,
                            use1D: use1D,
                            use3D: use3D,
                            size1D: size1D,
                            size3D: size3D,
                            input1D: input1D,
                            input3D: input3D)
    }

    static func parse1DLines(_ lines: [String],
                             expectedSize: Int,
                             startLine: Int) throws -> [LUTColor] {
        var colors: [LUTColor] = []
        colors.reserveCapacity(expectedSize)

        for (offset, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3,
                  let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else {
                throw LUTFormatterNucodaCMSError.invalidNumber(line: startLine + offset + 1)
            }
            colors.append(LUTColor.color(red: r, green: g, blue: b))
            if colors.count == expectedSize { break }
        }

        guard colors.count == expectedSize else {
            throw LUTFormatterNucodaCMSError.incompleteData(expected: expectedSize, actual: colors.count)
        }

        return colors
    }

    static func parse3DLines(_ lines: [String],
                             size: Int,
                             startLine: Int) throws -> [LUTColor] {
        let expected = size * size * size
        var colors: [LUTColor] = []
        colors.reserveCapacity(expected)

        for (offset, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3,
                  let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else {
                throw LUTFormatterNucodaCMSError.invalidNumber(line: startLine + offset + 1)
            }
            colors.append(LUTColor.color(red: r, green: g, blue: b))
            if colors.count == expected { break }
        }

        guard colors.count == expected else {
            throw LUTFormatterNucodaCMSError.incompleteData(expected: expected, actual: colors.count)
        }

        return colors
    }

    static func buildLUT1D(from colors: [LUTColor],
                           size: Int,
                           bounds: (Double, Double),
                           title: String?,
                           metadata: [String: Any],
                           description: String?) throws -> LUT1D {
        guard size == colors.count else {
            throw LUTFormatterNucodaCMSError.incompleteData(expected: size, actual: colors.count)
        }

        let red = colors.map { $0.red }
        let green = colors.map { $0.green }
        let blue = colors.map { $0.blue }

        var lut = LUT1D(redCurve: red,
                        greenCurve: green,
                        blueCurve: blue,
                        inputLowerBound: bounds.0,
                        inputUpperBound: bounds.1)
        lut.title = title
        lut.metadata = metadata
        lut.descriptionText = description
        return lut
    }

    static func buildLUT3D(from colors: [LUTColor],
                           size: Int,
                           bounds: (Double, Double),
                           title: String?,
                           metadata: [String: Any],
                           description: String?) throws -> LUT3D {
        guard colors.count == size * size * size else {
            throw LUTFormatterNucodaCMSError.incompleteData(expected: size * size * size, actual: colors.count)
        }

        var lut = LUT3D(size: size,
                         inputLowerBound: bounds.0,
                         inputUpperBound: bounds.1)
        for (index, color) in colors.enumerated() {
            let r = index % size
            let g = (index % (size * size)) / size
            let b = index / (size * size)
            lut.setColor(color, r: r, g: g, b: b)
        }
        lut.title = title
        lut.metadata = metadata
        lut.descriptionText = description
        return lut
    }

    static func normalizeLegacyPreLUT(_ lut: LUT1D, scale: Double) -> LUT1D {
        guard scale != 0 else { return lut }
        var normalized = lut
        for index in 0..<lut.size {
            let color = lut.colorAt(index: index)
            let adjusted = LUTColor.color(red: color.red / scale,
                                           green: color.green / scale,
                                           blue: color.blue / scale)
            normalized.setColor(adjusted, index: index)
        }
        return normalized
    }

    static func combineInternal(preLUT: LUT1D, cube: LUT3D) -> LUT3D {
        var result = cube
        let lattice = cube.asLUT()
        for r in 0..<cube.size {
            for g in 0..<cube.size {
                for b in 0..<cube.size {
                    let identity = lattice.identityColorAt(r: Double(r),
                                                           g: Double(g),
                                                           b: Double(b))
                    let preFiltered = preLUT.color(at: identity)
                    let finalColor = cube.color(at: preFiltered)
                    result.setColor(finalColor, r: r, g: g, b: b)
                }
            }
        }
        return result
    }
}

// MARK: - Writing Helpers

private extension LUTFormatterNucodaCMS {
    static func write1D(_ lut: LUT1D, variant: Variant) -> String {
        var lines: [String] = []
        appendMetadataLines(from: lut, into: &lines)

        lines.append("NUCODA_3D_CUBE \(variant.versionNumber)")
        lines.append("")

        if let title = lut.title, !title.isEmpty {
            lines.append("TITLE \"\(title)\"")
            lines.append("")
        }

        lines.append("LUT_1D_SIZE \(lut.size)")
        if variant == .v3 {
            lines.append(String(format: "LUT_1D_INPUT_RANGE %.3f %.3f", lut.inputLowerBound, lut.inputUpperBound))
        }
        lines.append("")

        for index in 0..<lut.size {
            let color = lut.colorAt(index: index)
            lines.append(formattedLine(color.red, color.green, color.blue))
        }

        return lines.joined(separator: "\n")
    }

    static func write3D(_ lut: LUT3D, variant: Variant) -> String {
        var lines: [String] = []
        appendMetadataLines(from: lut, into: &lines)

        lines.append("NUCODA_3D_CUBE \(variant.versionNumber)")
        lines.append("")

        if let title = lut.title, !title.isEmpty {
            lines.append("TITLE \"\(title)\"")
            lines.append("")
        }

        lines.append("LUT_3D_SIZE \(lut.size)")
        if variant == .v3 {
            lines.append(String(format: "LUT_3D_INPUT_RANGE %.3f %.3f", lut.inputLowerBound, lut.inputUpperBound))
        }
        lines.append("")

        for index in 0..<(lut.size * lut.size * lut.size) {
            let r = index % lut.size
            let g = (index % (lut.size * lut.size)) / lut.size
            let b = index / (lut.size * lut.size)
            let color = lut.colorAt(r: r, g: g, b: b)
            lines.append(formattedLine(color.red, color.green, color.blue))
        }

        return lines.joined(separator: "\n")
    }

    static func appendMetadataLines(from lut: LUTProtocol, into lines: inout [String]) {
        let metadataString = LUTMetadataFormatter.string(from: lut.metadata, description: lut.descriptionText)
        if !metadataString.isEmpty {
            metadataString
                .components(separatedBy: "\n")
                .forEach { lines.append($0) }
            lines.append("")
        }
    }

    static func formattedLine(_ red: Double, _ green: Double, _ blue: Double) -> String {
        let components = [red, green, blue].map { String(format: "%.6f", $0) }
        return components.joined(separator: "  ")
    }

    static func passthroughOptions(variant: Variant,
                                    lutType: LUTType) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": variant.rawValue,
                               "lutType": lutType.rawValue]]
    }

    static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else { return nil }
        if let variantName = formatterOptions["fileTypeVariant"] as? String,
           let variant = Variant(rawValue: variantName) {
            return Options(variant: variant)
        }
        return nil
    }
}

// MARK: - Protocol Bridge

private protocol LUTProtocol {
    var title: String? { get }
    var metadata: [String: Any] { get }
    var descriptionText: String? { get }
}

extension LUT1D: LUTProtocol { }
extension LUT3D: LUTProtocol { }

