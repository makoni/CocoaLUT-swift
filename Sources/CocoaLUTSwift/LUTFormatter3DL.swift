import Foundation

enum LUTFormatter3DLError: Error, Equatable, LocalizedError {
    case invalidData
    case malformedHeader
    case unsupportedSize
    case unsupportedVariant

    var errorDescription: String? {
        switch self {
        case .invalidData: return "3DL file contained invalid or incomplete data."
        case .malformedHeader: return "3DL file header could not be parsed."
        case .unsupportedSize: return "3DL file declared an unsupported table size."
        case .unsupportedVariant: return "Requested 3DL variant is not supported for this LUT size."
        }
    }
}

enum LUTFormatter3DL {
    static let formatterIdentifier = "3dl"

    enum Variant: String {
        case lustre = "Lustre"
        case nuke = "Nuke"
        case legacy = "Legacy"
    }

    struct Options {
        var variant: Variant
        var integerMaxOutput: Int
    }

    fileprivate struct ParsedHeader {
        var variant: Variant?
        var size: Int?
        var integerMaxOutput: Int?
        var metadata: [String: Any]
        var metadataDescription: String?
    }

    static func read(url: URL) throws -> LUT3D {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try read(string: contents)
    }

    static func read(string: String) throws -> LUT3D {
        let lines = string.components(separatedBy: .newlines)
        let (header, payloadStart) = try parseHeader(from: lines)
        guard let variant = header.variant,
              let size = header.size,
              let integerMaxOutput = header.integerMaxOutput else {
            throw LUTFormatter3DLError.malformedHeader
        }

        guard size > 1 else { throw LUTFormatter3DLError.unsupportedSize }
        let payloadLines = Array(lines[payloadStart..<lines.count])
        let expectedEntries = size * size * size
        var colors: [LUTColor] = []
        colors.reserveCapacity(expectedEntries)

        for line in payloadLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmed)
            guard components.count == 3,
                  components.allSatisfy(LUTStringHelper.stringIsValidNumber),
                  let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else { continue }

            let divisor = Double(integerMaxOutput)
            guard divisor > 0 else { throw LUTFormatter3DLError.malformedHeader }
            let clampRange = 0.0...divisor
            let normalized = LUTColor.color(
                red: max(clampRange.lowerBound, min(clampRange.upperBound, r)) / divisor,
                green: max(clampRange.lowerBound, min(clampRange.upperBound, g)) / divisor,
                blue: max(clampRange.lowerBound, min(clampRange.upperBound, b)) / divisor
            )
            colors.append(normalized)
            if colors.count == expectedEntries { break }
        }

        guard colors.count == expectedEntries else { throw LUTFormatter3DLError.invalidData }

        var lut = LUT3D(size: size,
                        inputLowerBound: 0.0,
                        inputUpperBound: 1.0)
        for (index, color) in colors.enumerated() {
            let rIndex = index / (size * size)
            let gIndex = (index % (size * size)) / size
            let bIndex = index % size
            lut.setColor(color, r: rIndex, g: gIndex, b: bIndex)
        }

        lut.metadata = header.metadata
        lut.descriptionText = header.metadataDescription
        lut.passthroughFileOptions = passthroughOptions(variant: variant,
                                                        integerMaxOutput: integerMaxOutput,
                                                        size: size)
        return lut
    }

    static func write(_ lut: LUT3D, options: Options? = nil) throws -> String {
        let resolvedOptions = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? Options(variant: .nuke, integerMaxOutput: LUTMath.maxInteger(bitDepth: 16))

        guard resolvedOptions.integerMaxOutput > 0 else {
            throw LUTFormatter3DLError.malformedHeader
        }

        let headerLines = try headerLines(for: resolvedOptions.variant,
                                          lut: lut,
                                          integerMaxOutput: resolvedOptions.integerMaxOutput)

        var rows: [String] = []
        rows.reserveCapacity(lut.size * lut.size * lut.size)

        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    let color = lut.colorAt(r: r, g: g, b: b)
                    let red = quantize(color.red, max: resolvedOptions.integerMaxOutput)
                    let green = quantize(color.green, max: resolvedOptions.integerMaxOutput)
                    let blue = quantize(color.blue, max: resolvedOptions.integerMaxOutput)
                    rows.append("\(red) \(green) \(blue)")
                }
            }
        }

        let metadataString = LUTMetadataFormatter.string(from: lut.metadata,
                                                         description: lut.descriptionText)
        var lines: [String] = []
        if !metadataString.isEmpty {
            lines.append(contentsOf: metadataString.components(separatedBy: "\n"))
        }
        lines.append(contentsOf: headerLines)
        lines.append("")
        lines.append(contentsOf: rows)

        return lines.joined(separator: "\n")
    }
}

// MARK: - Private Helpers

private extension LUTFormatter3DL {
    private static func parseHeader(from lines: [String]) throws -> (ParsedHeader, Int) {
        guard let payloadIndex = LUTStringHelper.findFirstLUTLine(in: lines,
                                                                  separator: " ",
                                                                  valueCount: 3) else {
            throw LUTFormatter3DLError.malformedHeader
        }

        let headerLines = Array(lines[..<payloadIndex])
        let metadata = LUTMetadataFormatter.metadataAndDescription(from: headerLines)
        var header = ParsedHeader(variant: nil,
                                  size: nil,
                                  integerMaxOutput: nil,
                                  metadata: metadata.metadata,
                                  metadataDescription: metadata.description)

        for rawLine in headerLines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.range(of: "Mesh", options: .caseInsensitive) != nil {
                let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
                guard components.count >= 3,
                      let inputDepth = Int(components[1]),
                      let outputDepth = Int(components[2]) else { continue }

                let size = Int(pow(2.0, Double(inputDepth))) + 1
                let integerMaxOutput = LUTMath.maxInteger(bitDepth: outputDepth)
                header.variant = .lustre
                header.size = size
                header.integerMaxOutput = integerMaxOutput
                break
            }

            if line.hasPrefix("#") { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(line)
            guard !components.isEmpty,
                  components.allSatisfy(LUTStringHelper.stringIsValidNumber) else { continue }

            let values = components.compactMap(Int.init)
            guard values.count == components.count else { continue }

            var integerMaxOutput = values.last ?? 0
            var variant: Variant = .nuke
            if integerMaxOutput == 1023 {
                integerMaxOutput = LUTMath.maxInteger(bitDepth: 12)
                variant = .legacy
            }

            header.variant = variant
            header.size = values.count
            header.integerMaxOutput = integerMaxOutput
            break
        }

        guard header.variant != nil,
              header.size != nil,
              header.integerMaxOutput != nil else {
            throw LUTFormatter3DLError.malformedHeader
        }

        return (header, payloadIndex)
    }

    static func headerLines(for variant: Variant,
                            lut: LUT3D,
                            integerMaxOutput: Int) throws -> [String] {
        let size = lut.size
        switch variant {
        case .nuke:
            let indices = LUTMath.indicesIntegerArray(start: 0,
                                                       end: integerMaxOutput,
                                                       count: size)
            return [indices.map(String.init).joined(separator: " ")]
        case .legacy:
            let indices = LUTMath.indicesIntegerArrayLegacy(start: 0,
                                                             end: 1023,
                                                             count: size)
            return [indices.map(String.init).joined(separator: " ")]
        case .lustre:
            guard size > 1 else { throw LUTFormatter3DLError.unsupportedSize }
            let depth = log2(Double(size - 1))
            guard depth.rounded(.towardZero) == depth else {
                throw LUTFormatter3DLError.unsupportedVariant
            }

            let outputDepth = log2(Double(integerMaxOutput + 1))
            guard outputDepth.rounded(.towardZero) == outputDepth else {
                throw LUTFormatter3DLError.unsupportedVariant
            }

            let indices = LUTMath.indicesIntegerArrayLegacy(start: 0,
                                                             end: 1023,
                                                             count: size)
            return [
                "3DMESH",
                "Mesh \(Int(depth)) \(Int(outputDepth))",
                indices.map(String.init).joined(separator: " ")
            ]
        }
    }

    static func quantize(_ value: Double, max maximum: Int) -> Int {
        guard maximum > 0 else { return 0 }
        let scaled = Int((value * Double(maximum)).rounded(.down))
        return max(0, min(maximum, scaled))
    }

    static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any],
              let rawVariant = formatterOptions["fileTypeVariant"] as? String,
              let variant = Variant(rawValue: rawVariant) else { return nil }

        if let intValue = formatterOptions["integerMaxOutput"] as? Int {
            return Options(variant: variant, integerMaxOutput: intValue)
        }
        if let number = formatterOptions["integerMaxOutput"] as? NSNumber {
            return Options(variant: variant, integerMaxOutput: number.intValue)
        }
        return nil
    }

    static func passthroughOptions(variant: Variant,
                                   integerMaxOutput: Int,
                                   size: Int) -> [String: Any] {
        [formatterIdentifier: [
            "fileTypeVariant": variant.rawValue,
            "integerMaxOutput": integerMaxOutput,
            "lutSize": size
        ]]
    }
}
