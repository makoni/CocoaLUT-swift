import Foundation

enum LUTFormatterClipsterError: Error, Equatable, LocalizedError {
    case invalidXML
    case missingAttribute(String)
    case invalidNumber(line: Int, column: Int)
    case incompleteData(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .invalidXML:
            return "Clipster LUT XML could not be parsed."
        case .missingAttribute(let name):
            return "Clipster LUT XML is missing required attribute \(name)."
        case .invalidNumber(let line, let column):
            return "Encountered a non-numeric value while parsing Clipster LUT at line \(line), column \(column)."
        case .incompleteData(let expected, let actual):
            return "Clipster LUT contained \(actual) entries but \(expected) were required."
        }
    }
}

enum LUTFormatterClipster {
    static let formatterIdentifier = "clipster"

    struct Options {
        var lutSize: Int
        var integerMaxOutput: Int

        init(lutSize: Int = 17,
             integerMaxOutput: Int = LUTMath.maxInteger(bitDepth: 16)) {
            self.lutSize = lutSize
            self.integerMaxOutput = integerMaxOutput
        }
    }

    static func read(url: URL) throws -> LUT3D {
        let data = try Data(contentsOf: url)
        return try read(data: data)
    }

    static func read(data: Data) throws -> LUT3D {
        let parserDelegate = ClipsterXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw LUTFormatterClipsterError.invalidXML
        }

        guard let size = parserDelegate.size else {
            throw LUTFormatterClipsterError.missingAttribute("N")
        }

        guard let bitDepth = parserDelegate.bitDepth else {
            throw LUTFormatterClipsterError.missingAttribute("BitDepth")
        }

        guard let rawValues = parserDelegate.values else {
            throw LUTFormatterClipsterError.missingAttribute("values")
        }

        let integerMaxOutput = LUTMath.maxInteger(bitDepth: bitDepth)
        let expectedEntries = size * size * size

        var lut = LUT3D(size: size, inputLowerBound: 0, inputUpperBound: 1)
        lut.title = parserDelegate.name

        var index = 0
        let lines = rawValues.components(separatedBy: .newlines)
        for (lineNumber, rawLine) in lines.enumerated() {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else { continue }
            let components = LUTStringHelper.componentsSeparatedByWhitespace(trimmedLine)
            guard components.count == 3 else { continue }

            let values = try components.enumerated().map { column, token -> Int in
                guard let doubleValue = Double(token) else {
                    throw LUTFormatterClipsterError.invalidNumber(line: lineNumber + 1, column: column + 1)
                }
                return Int(doubleValue.rounded())
            }

            let color = LUTColor.fromIntegers(maxOutputValue: integerMaxOutput,
                                              red: values[0],
                                              green: values[1],
                                              blue: values[2])

            let rIndex = index / (size * size)
            let gIndex = (index % (size * size)) / size
            let bIndex = index % size
            lut.setColor(color, r: rIndex, g: gIndex, b: bIndex)
            index += 1
        }

        guard index == expectedEntries else {
            throw LUTFormatterClipsterError.incompleteData(expected: expectedEntries, actual: index)
        }

        lut.passthroughFileOptions = passthroughOptions(lutSize: size,
                                                        integerMaxOutput: integerMaxOutput)
        return lut
    }

    static func read(string: String) throws -> LUT3D {
        guard let data = string.data(using: .utf8) else {
            throw LUTFormatterClipsterError.invalidXML
        }
        return try read(data: data)
    }

    static func write(_ lut: LUT3D, options: Options? = nil) throws -> String {
        let resolvedOptions = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? Options(lutSize: lut.size)

        let workingLUT = lut.size == resolvedOptions.lutSize ? lut : lut.resized(to: resolvedOptions.lutSize)
        let maxOutput = resolvedOptions.integerMaxOutput
        let bitDepth = bitDepthFor(maxOutput: maxOutput)

        var rows: [String] = []
        rows.reserveCapacity(workingLUT.size * workingLUT.size * workingLUT.size)

        for index in 0..<(workingLUT.size * workingLUT.size * workingLUT.size) {
            let rIndex = index / (workingLUT.size * workingLUT.size)
            let gIndex = (index % (workingLUT.size * workingLUT.size)) / workingLUT.size
            let bIndex = index % workingLUT.size
            let color = workingLUT.colorAt(r: rIndex, g: gIndex, b: bIndex)
            let converted = quantized(color, maxOutput: maxOutput)
            rows.append("\(converted.red) \(converted.green) \(converted.blue)")
        }

        var xml: [String] = []
        let title = lut.title ?? ""
        xml.append("<LUT3D name='\(xmlEscaped(title))' N='\(workingLUT.size)' BitDepth='\(bitDepth)'>")
        xml.append("<values>")
        xml.append(contentsOf: rows)
        xml.append("</values>")
        xml.append("</LUT3D>")
        return xml.joined(separator: "\n")
    }

    private static func quantized(_ color: LUTColor, maxOutput: Int) -> (red: Int, green: Int, blue: Int) {
        let clamp: (Double) -> Int = { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            return Int((clamped * Double(maxOutput)).rounded(.down))
        }
        return (clamp(color.red), clamp(color.green), clamp(color.blue))
    }

    private static func bitDepthFor(maxOutput: Int) -> Int {
        guard maxOutput > 0 else { return 0 }
        return Int(round(log2(Double(maxOutput + 1))))
    }

    private static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any] else { return nil }
        let lutSize = (formatterOptions["lutSize"] as? NSNumber)?.intValue
        let integerMax = (formatterOptions["integerMaxOutput"] as? NSNumber)?.intValue
        switch (lutSize, integerMax) {
        case let (size?, max?):
            return Options(lutSize: size, integerMaxOutput: max)
        case let (size?, nil):
            return Options(lutSize: size)
        case let (nil, max?):
            return Options(integerMaxOutput: max)
        default:
            return nil
        }
    }

    private static func passthroughOptions(lutSize: Int, integerMaxOutput: Int) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": "Clipster",
                               "lutSize": lutSize,
                               "integerMaxOutput": integerMaxOutput]]
    }

    private static func xmlEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private final class ClipsterXMLParser: NSObject, XMLParserDelegate {
    var name: String?
    var size: Int?
    var bitDepth: Int?
    var values: String?

    private var collectingValues = false
    private var buffer = String()

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "LUT3D" {
            name = attributeDict["name"]
            size = attributeDict["N"].flatMap { Int($0) }
            bitDepth = attributeDict["BitDepth"].flatMap { Int($0) }
        } else if elementName == "values" {
            collectingValues = true
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard collectingValues else { return }
        buffer.append(string)
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "values" {
            collectingValues = false
            values = buffer
        }
    }
}
