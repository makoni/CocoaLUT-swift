import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTFormatterClipsterTests {
    private let sampleXML = """
    <LUT3D name='Sample' N='2' BitDepth='10'>
    <values>
    0 0 0
    0 0 1023
    0 1023 0
    0 1023 1023
    1023 0 0
    1023 0 1023
    1023 1023 0
    1023 1023 1023
    </values>
    </LUT3D>
    """

    @Test
    func testReadParsesXMLAndNormalizesValues() throws {
        let lut = try LUTFormatterClipster.read(string: sampleXML)
        #expect(lut.size == 2)
        #expect(lut.title == "Sample")

        let maxValue = Double(LUTMath.maxInteger(bitDepth: 10))
        #expect(abs(lut.colorAt(r: 1, g: 1, b: 1).red - 1) <= 1e-6)
        #expect(abs(lut.colorAt(r: 0, g: 1, b: 0).green - (1023.0 / maxValue)) <= 1e-6)

        let passthrough = lut.passthroughFileOptions[LUTFormatterClipster.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["lutSize"] as? Int == 2)
        #expect(passthrough?["integerMaxOutput"] as? Int == Int(maxValue))
    }

    @Test
    func testWriteProducesClipsterXML() throws {
        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.title = "Sample"
        lut.passthroughFileOptions = [LUTFormatterClipster.formatterIdentifier: ["lutSize": 2,
                                                                                 "integerMaxOutput": LUTMath.maxInteger(bitDepth: 10)]]

        let xml = try LUTFormatterClipster.write(lut)
        #expect(xml.contains("<LUT3D"))
        #expect(xml.contains("N='2'"))
        #expect(xml.contains("BitDepth='10'"))
        #expect(xml.contains("<values>"))
        #expect(xml.contains("0 0 0"))
    }

    @Test
    func testWriteResizesWhenOptionsDemandDifferentSize() throws {
        let lut = LUT3D.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let xml = try LUTFormatterClipster.write(lut, options: .init(lutSize: 2, integerMaxOutput: LUTMath.maxInteger(bitDepth: 10)))
        #expect(xml.contains("N='2'"))
    }
}
