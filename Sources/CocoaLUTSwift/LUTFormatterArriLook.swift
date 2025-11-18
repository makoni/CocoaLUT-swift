import Foundation

enum LUTFormatterArriLookError: Error, Equatable, LocalizedError {
    case invalidXML
    case unsupportedVersion(String?)
    case missingElement(String)
    case invalidTriple(String)
    case invalidToneMapValue(index: Int)
    case toneMapCountMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .invalidXML:
            return "Unable to parse Arri Look XML content."
        case .unsupportedVersion(let version):
            return "Arri Look version is not supported: \(version ?? "unknown")."
        case .missingElement(let name):
            return "Arri Look XML is missing required element: \(name)."
        case .invalidTriple(let element):
            return "Arri Look element \(element) does not contain exactly three numeric values."
        case .invalidToneMapValue(let index):
            return "Tone map entry \(index) is not a valid integer."
        case .toneMapCountMismatch(let expected, let actual):
            return "Tone map rows attribute declared \(expected) entries but found \(actual)."
        }
    }
}

enum LUTFormatterArriLook {
    static let formatterIdentifier = "arriLook"

    struct Options {
        var lutSize: Int
    }

    static func read(url: URL) throws -> LUT3D {
        let data = try Data(contentsOf: url)
        return try read(data: data)
    }

    static func read(string: String) throws -> LUT3D {
        guard let data = string.data(using: .utf8) else {
            throw LUTFormatterArriLookError.invalidXML
        }
        return try read(data: data)
    }

    static func read(data: Data) throws -> LUT3D {
        let parser = ArriLookParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse(), let payload = parser.payload else {
            throw parser.error ?? LUTFormatterArriLookError.invalidXML
        }

        guard payload.version == "1.0" else {
            throw LUTFormatterArriLookError.unsupportedVersion(payload.version)
        }

        let curve = payload.toneMapValues.map { Double($0) / 4095.0 }
        let toneMap = LUT1D(redCurve: curve,
                            greenCurve: curve,
                            blueCurve: curve,
                            inputLowerBound: 0,
                            inputUpperBound: 1)

        let printerLight = LUTColor.color(red: payload.printerLight[0],
                                          green: payload.printerLight[1],
                                          blue: payload.printerLight[2])

        var lut = LUT3D.identity(size: 33, inputLowerBound: 0, inputUpperBound: 1)
        lut.loop { r, g, b in
            let original = lut.colorAt(r: r, g: g, b: b)
            var color = original.changingSaturation(payload.saturation,
                                                    lumaR: 0.291948669899,
                                                    lumaG: 0.823830265984,
                                                    lumaB: -0.115778935883)
            color = color.adding(printerLight)
            color = toneMap.color(at: color)
            color = color.applyingSlopeOffsetPower(redSlope: payload.slope[0],
                                                   redOffset: payload.offset[0],
                                                   redPower: payload.power[0],
                                                   greenSlope: payload.slope[1],
                                                   greenOffset: payload.offset[1],
                                                   greenPower: payload.power[1],
                                                   blueSlope: payload.slope[2],
                                                   blueOffset: payload.offset[2],
                                                   bluePower: payload.power[2])
            lut.setColor(color, r: r, g: g, b: b)
        }

        lut.passthroughFileOptions = passthroughOptions(lutSize: payload.toneMapValues.count)
        return lut
    }

    static func write(_ lut: LUT1D, options: Options? = nil) throws -> String {
        let resolved = options
            ?? Self.options(from: lut.passthroughFileOptions)
            ?? Options(lutSize: 4096)

        let toneMap = lut.size == resolved.lutSize ? lut : lut.resized(to: resolved.lutSize)
        var rows: [String] = []
        rows.reserveCapacity(resolved.lutSize)
        for index in 0..<resolved.lutSize {
            let value = toneMap.valueAtR(index)
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            let quantized = Int((clamped * 4095.0).rounded())
            rows.append("\t\(quantized)")
        }

        let header = """
        <!-- ARRI Digital Camera Look File -->
        <!-- This XML format is used to import color settings into the camera("look file")-->
        <adicam version=\"1.0\" camera=\"alexa\">
        \t<Saturation>
        \t\t1.000000
        \t</Saturation>
        \t<PrinterLight>
        \t\t0.000000 0.000000 0.000000
        \t</PrinterLight>
        \t<SOPNode>
        \t\t<Slope>1.000000 1.000000 1.000000</Slope>
        \t\t<Offset>0.000000 0.000000 0.000000</Offset>
        \t\t<Power>1.000000 1.000000 1.000000</Power>
        \t</SOPNode>
        \t<ToneMapLut rows=\"\(resolved.lutSize)\" cols=\"1\">
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let footer = """
        \t</ToneMapLut>
        </adicam>
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let body = ([header] + rows + [footer]).joined(separator: "\n")
        return body
    }

    private static func passthroughOptions(lutSize: Int) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": "Arri",
                               "lutSize": lutSize]]
    }

    private static func options(from options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else {
            return nil
        }
        if let lutSize = (formatterOptions["lutSize"] as? NSNumber)?.intValue ?? formatterOptions["lutSize"] as? Int {
            return Options(lutSize: lutSize)
        }
        return nil
    }
}

private final class ArriLookParser: NSObject, XMLParserDelegate {
    struct Payload {
        var version: String
        var saturation: Double
        var printerLight: [Double]
        var slope: [Double]
        var offset: [Double]
        var power: [Double]
        var toneMapValues: [Int]
    }

    private(set) var payload: Payload?
    private(set) var error: Error?

    private var version: String?
    private var saturation: Double?
    private var printerLight: [Double]?
    private var slope: [Double]?
    private var offset: [Double]?
    private var power: [Double]?
    private var toneMapRows: Int?
    private var toneMapValues: [Int] = []

    private var currentElement: String?
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        buffer = ""
        if elementName == "adicam" {
            version = attributeDict["version"]
        } else if elementName == "ToneMapLut" {
            toneMapRows = attributeDict["rows"].flatMap(Int.init)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "Saturation":
            saturation = Double(trimmed)
        case "PrinterLight":
            printerLight = parseTriple(trimmed, element: elementName, parser: parser)
        case "Slope":
            slope = parseTriple(trimmed, element: elementName, parser: parser)
        case "Offset":
            offset = parseTriple(trimmed, element: elementName, parser: parser)
        case "Power":
            power = parseTriple(trimmed, element: elementName, parser: parser)
        case "ToneMapLut":
            parseToneMap(trimmed, parser: parser)
        default:
            break
        }
        buffer = ""
        currentElement = nil
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        guard error == nil else { return }
        guard let version, let saturation, let printerLight, let slope, let offset, let power else {
            error = LUTFormatterArriLookError.missingElement(currentElement ?? "unknown")
            return
        }
        guard !toneMapValues.isEmpty else {
            error = LUTFormatterArriLookError.missingElement("ToneMapLut")
            return
        }
        payload = Payload(version: version,
                          saturation: saturation,
                          printerLight: printerLight,
                          slope: slope,
                          offset: offset,
                          power: power,
                          toneMapValues: toneMapValues)
    }

    private func parseTriple(_ string: String, element: String, parser: XMLParser) -> [Double]? {
        let components = string.split(whereSeparator: { $0.isWhitespace })
        guard components.count == 3 else {
            register(error: LUTFormatterArriLookError.invalidTriple(element), parser: parser)
            return nil
        }
        let values = components.compactMap(Double.init)
        guard values.count == 3 else {
            register(error: LUTFormatterArriLookError.invalidTriple(element), parser: parser)
            return nil
        }
        return values
    }

    private func parseToneMap(_ string: String, parser: XMLParser) {
        guard let rows = toneMapRows else {
            register(error: LUTFormatterArriLookError.missingElement("ToneMapLut rows"), parser: parser)
            return
        }
        toneMapValues.removeAll(keepingCapacity: true)
        let lines = string.split(separator: "\n")
        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let components = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard components.count == 1, let value = Int(components[0]) else {
                register(error: LUTFormatterArriLookError.invalidToneMapValue(index: index), parser: parser)
                return
            }
            toneMapValues.append(value)
        }
        if toneMapValues.count != rows {
            register(error: LUTFormatterArriLookError.toneMapCountMismatch(expected: rows, actual: toneMapValues.count), parser: parser)
        }
    }

    private func register(error: Error, parser: XMLParser) {
        self.error = error
        parser.abortParsing()
    }
}
