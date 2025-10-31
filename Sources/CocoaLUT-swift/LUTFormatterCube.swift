import Foundation
import simd

enum LUTCubeFormatterError: Error, Equatable, LocalizedError {
    case invalidData
    case unsupportedSize
    case malformedHeader

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Cube file contained invalid or incomplete data."
        case .unsupportedSize: return "Cube file declared an unsupported table size."
        case .malformedHeader: return "Cube file header could not be parsed."
        }
    }
}

enum LUTCubeVariant: String {
    case resolve = "Resolve"
    case resolveLegacy = "Resolve Legacy"
    case highPrecision = "High Precision"
    case iridasAdobe = "Iridas/Adobe"

    var decimalPlaces: Int {
        switch self {
        case .resolve: return 10
        case .resolveLegacy, .iridasAdobe: return 6
        case .highPrecision: return 12
        }
    }
}

struct LUTCubeOptions {
    var variant: LUTCubeVariant

    static let `default` = LUTCubeOptions(variant: .resolve)
}

enum LUTCubeResult {
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

enum LUTCubeFormatter {
    static let formatterIdentifier = "cube"
    static let legacyFormatterIdentifier = "com.cocoalut.formatter.cube"

    struct ParsedHeader {
        var title: String?
        var variant: LUTCubeVariant?
        var size1D: Int?
        var size3D: Int?
        var inputLowerBound: Double?
        var inputUpperBound: Double?
        var metadata: [String: Any]
        var metadataDescription: String?
    }

    // MARK: Reading

    static func read(url: URL) throws -> LUTCubeResult {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func read(string: String) throws -> LUTCubeResult {
        let allLines = string.components(separatedBy: .newlines)
        let (header, payloadStart) = try parseHeader(from: allLines)
        guard payloadStart < allLines.count else { throw LUTCubeFormatterError.invalidData }
        let payloadLines = Array(allLines[payloadStart..<allLines.count])

        if let size = header.size3D {
            return try parse3DLUT(size: size,
                                 inputLowerBound: header.inputLowerBound,
                                 inputUpperBound: header.inputUpperBound,
                                 variant: header.variant,
                                 title: header.title,
                                 metadata: header.metadata,
                                 description: header.metadataDescription,
                                 payloadLines: payloadLines)
        } else if let size = header.size1D {
            return try parse1DLUT(size: size,
                                 inputLowerBound: header.inputLowerBound,
                                 inputUpperBound: header.inputUpperBound,
                                 variant: header.variant,
                                 title: header.title,
                                 metadata: header.metadata,
                                 description: header.metadataDescription,
                                 payloadLines: payloadLines)
        }

        throw LUTCubeFormatterError.malformedHeader
    }

    // MARK: Writing

    static func write(_ result: LUTCubeResult, options: LUTCubeOptions? = nil) throws -> String {
        switch result {
        case .lut1D(let lut):
            return try write1D(lut, variantOverride: options?.variant)
        case .lut3D(let lut):
            return try write3D(lut, variantOverride: options?.variant)
        }
    }
}

// MARK: - Private Helpers

private extension LUTCubeFormatter {
    static func parseHeader(from lines: [String]) throws -> (ParsedHeader, Int) {
        var header = ParsedHeader(title: nil,
                                  variant: nil,
                                  size1D: nil,
                                  size3D: nil,
                                  inputLowerBound: nil,
                                  inputUpperBound: nil,
                                  metadata: [:],
                                  metadataDescription: nil)

    var metadataLines: [String] = []
    var payloadIndex = lines.count

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#") {
                metadataLines.append(line)
                continue
            }

            let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
            if components.count == 3,
               components.allSatisfy(LUTStringHelper.stringIsValidNumber) {
                payloadIndex = index
                break
            }

            if line.uppercased().hasPrefix("TITLE") {
                if let firstQuote = line.firstIndex(of: "\"") {
                    let remainder = line[line.index(after: firstQuote)...]
                    if let lastQuote = remainder.lastIndex(of: "\"") {
                        header.title = String(remainder[..<lastQuote])
                    }
                }
                continue
            }

            if line.uppercased().hasPrefix("LUT_1D_SIZE") {
                guard let size = parseLastNumber(in: line) else { throw LUTCubeFormatterError.malformedHeader }
                header.size1D = Int(size)
                continue
            }

            if line.uppercased().hasPrefix("LUT_3D_SIZE") {
                guard let size = parseLastNumber(in: line) else { throw LUTCubeFormatterError.malformedHeader }
                header.size3D = Int(size)
                continue
            }

            if line.uppercased().hasPrefix("LUT_1D_INPUT_RANGE") || line.uppercased().hasPrefix("LUT_3D_INPUT_RANGE") {
                guard components.count >= 3,
                      let lower = Double(components[components.count - 2]),
                      let upper = Double(components.last!) else {
                    throw LUTCubeFormatterError.malformedHeader
                }
                header.inputLowerBound = lower
                header.inputUpperBound = upper
                if header.variant == nil {
                    header.variant = variant(from: components.last ?? "")
                }
                continue
            }

            if line.uppercased().hasPrefix("DOMAIN_MIN") {
                let values = components.dropFirst().compactMap(Double.init)
                guard !values.isEmpty else { throw LUTCubeFormatterError.malformedHeader }
                header.inputLowerBound = values.first
                header.variant = .iridasAdobe
                continue
            }

            if line.uppercased().hasPrefix("DOMAIN_MAX") {
                let values = components.dropFirst().compactMap(Double.init)
                guard !values.isEmpty else { throw LUTCubeFormatterError.malformedHeader }
                header.inputUpperBound = values.first
                header.variant = .iridasAdobe
                continue
            }
        }

        let metadata = LUTMetadataFormatter.metadataAndDescription(from: metadataLines)
        header.metadata = metadata.metadata
        header.metadataDescription = metadata.description

        guard payloadIndex != lines.count else { throw LUTCubeFormatterError.invalidData }

        return (header, payloadIndex)
    }

    static func parse1DLUT(size: Int,
                           inputLowerBound: Double?,
                           inputUpperBound: Double?,
                           variant: LUTCubeVariant?,
                           title: String?,
                           metadata: [String: Any],
                           description: String?,
                           payloadLines: [String]) throws -> LUTCubeResult {
        guard size > 0 else { throw LUTCubeFormatterError.unsupportedSize }

        var red: [Double] = []
        var green: [Double] = []
        var blue: [Double] = []
        var firstSample: String?

        for line in payloadLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3,
                  let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else { continue }
            red.append(r)
            green.append(g)
            blue.append(b)
            if firstSample == nil { firstSample = components[0] }
            if red.count == size { break }
        }

        guard red.count == size else { throw LUTCubeFormatterError.invalidData }

        let lower = inputLowerBound ?? 0
        let upper = inputUpperBound ?? 1
        var lut = LUT1D(redCurve: red,
                        greenCurve: green,
                        blueCurve: blue,
                        inputLowerBound: lower,
                        inputUpperBound: upper)
        lut.title = title
        lut.metadata = metadata
        let resolvedVariant = variant ?? resolvedVariant(fromSample: firstSample)
        lut.passthroughFileOptions = passthroughOptions(variant: resolvedVariant)
        lut.descriptionText = description
        return .lut1D(lut)
    }

    static func parse3DLUT(size: Int,
                           inputLowerBound: Double?,
                           inputUpperBound: Double?,
                           variant: LUTCubeVariant?,
                           title: String?,
                           metadata: [String: Any],
                           description: String?,
                           payloadLines: [String]) throws -> LUTCubeResult {
        guard size > 1 else { throw LUTCubeFormatterError.unsupportedSize }
        let expectedEntries = size * size * size
        var colors: [SIMD3<Double>] = []
        colors.reserveCapacity(expectedEntries)
        var firstSample: String?

        for line in payloadLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3,
                  let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else { continue }
            colors.append(SIMD3(r, g, b))
            if firstSample == nil { firstSample = components[0] }
            if colors.count == expectedEntries { break }
        }

        guard colors.count == expectedEntries else { throw LUTCubeFormatterError.invalidData }

        let lower = inputLowerBound ?? 0
        let upper = inputUpperBound ?? 1
        var lut = LUT3D(size: size,
                        inputLowerBound: lower,
                        inputUpperBound: upper)
        lut.title = title
        lut.metadata = metadata
        lut.descriptionText = description
        let resolvedVariant = variant ?? resolvedVariant(fromSample: firstSample)
        lut.passthroughFileOptions = passthroughOptions(variant: resolvedVariant)

        for (index, color) in colors.enumerated() {
            let rIndex = index % size
            let gIndex = (index / size) % size
            let bIndex = index / (size * size)
            lut.setColor(LUTColor.color(red: color.x, green: color.y, blue: color.z),
                         r: rIndex, g: gIndex, b: bIndex)
        }

        return .lut3D(lut)
    }

    static func write1D(_ lut: LUT1D, variantOverride: LUTCubeVariant?) throws -> String {
        let variant = variantOverride ?? variantFromPassthrough(options: lut.passthroughFileOptions) ?? .resolve
        let header = headerString(for: lut,
                                  sizeDirective: "LUT_1D_SIZE \(lut.size)",
                                  inputDirective: "LUT_1D_INPUT_RANGE \(formatted(lut.inputLowerBound, variant: variant)) \(formatted(lut.inputUpperBound, variant: variant))",
                                  variant: variant)

        let body = (0..<lut.size).map { index -> String in
            let r = formatted(lut.valueAtR(index), variant: variant)
            let g = formatted(lut.valueAtG(index), variant: variant)
            let b = formatted(lut.valueAtB(index), variant: variant)
            return "\(r) \(g) \(b)"
        }.joined(separator: "\n")

        return [header, body].joined(separator: "\n")
    }

    static func write3D(_ lut: LUT3D, variantOverride: LUTCubeVariant?) throws -> String {
        let variant = variantOverride ?? variantFromPassthrough(options: lut.passthroughFileOptions) ?? .resolve
        let header = headerString(for: lut,
                                  sizeDirective: "LUT_3D_SIZE \(lut.size)",
                                  inputDirective: "LUT_3D_INPUT_RANGE \(formatted(lut.inputLowerBound, variant: variant)) \(formatted(lut.inputUpperBound, variant: variant))",
                                  variant: variant)

        var rows: [String] = []
        rows.reserveCapacity(lut.size * lut.size * lut.size)
        for b in 0..<lut.size {
            for g in 0..<lut.size {
                for r in 0..<lut.size {
                    let color = lut.colorAt(r: r, g: g, b: b)
                    let formattedRow = [color.red, color.green, color.blue]
                        .map { formatted($0, variant: variant) }
                        .joined(separator: " ")
                    rows.append(formattedRow)
                }
            }
        }

        return ([header] + rows).joined(separator: "\n")
    }

    static func headerString(for lut: LUTProtocol,
                             sizeDirective: String,
                             inputDirective: String,
                             variant: LUTCubeVariant) -> String {
        var sections: [String] = []
        if let title = lut.title {
            sections.append("TITLE \"\(title)\"")
        }

        let metadataString = LUTMetadataFormatter.string(from: lut.metadata, description: lut.descriptionText)
        if !metadataString.isEmpty {
            sections.append(contentsOf: metadataString.components(separatedBy: "\n"))
        }

        sections.append(sizeDirective)
        sections.append(inputDirective)

        if variant == .iridasAdobe {
            sections.append("DOMAIN_MIN \(formatted(lut.inputLowerBound, variant: variant)) \(formatted(lut.inputLowerBound, variant: variant)) \(formatted(lut.inputLowerBound, variant: variant))")
            sections.append("DOMAIN_MAX \(formatted(lut.inputUpperBound, variant: variant)) \(formatted(lut.inputUpperBound, variant: variant)) \(formatted(lut.inputUpperBound, variant: variant))")
        }

        return sections.joined(separator: "\n")
    }

    static func parseLastNumber(in line: String) -> Double? {
        let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
        guard let last = components.last else { return nil }
        return Double(last)
    }

    static func formatted(_ value: Double, variant: LUTCubeVariant) -> String {
        return String(format: "%.\(variant.decimalPlaces)f", value)
    }

    static func variant(from text: String) -> LUTCubeVariant {
        let decimalCount = text.split(separator: ".").last?.count ?? 0
        switch decimalCount {
        case 12: return .highPrecision
        case 10: return .resolve
        case 6: return .resolveLegacy
        default: return .resolveLegacy
        }
    }

    static func resolvedVariant(fromSample sample: String?) -> LUTCubeVariant {
        guard let sample else { return .resolveLegacy }
        return variant(from: sample)
    }

    static func variantFromPassthrough(options: [String: Any]) -> LUTCubeVariant? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any],
              let rawValue = formatterOptions["fileTypeVariant"] as? String else { return nil }
        return LUTCubeVariant(rawValue: rawValue)
    }

    static func passthroughOptions(variant: LUTCubeVariant) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": variant.rawValue]]
    }
}

private protocol LUTProtocol {
    var title: String? { get set }
    var metadata: [String: Any] { get set }
    var descriptionText: String? { get set }
    var inputLowerBound: Double { get }
    var inputUpperBound: Double { get }
}

extension LUT1D: LUTProtocol {}
extension LUT3D: LUTProtocol {}
