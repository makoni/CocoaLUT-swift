import XCTest
@testable import CocoaLUT_swift

final class LUTFormatterClipsterTests: XCTestCase {
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

    func testReadParsesXMLAndNormalizesValues() throws {
        let lut = try LUTFormatterClipster.read(string: sampleXML)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.title, "Sample")

        let maxValue = Double(LUTMath.maxInteger(bitDepth: 10))
        XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).red, 1, accuracy: 1e-6)
        XCTAssertEqual(lut.colorAt(r: 0, g: 1, b: 0).green, 1023.0 / maxValue, accuracy: 1e-6)

        let passthrough = lut.passthroughFileOptions[LUTFormatterClipster.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["lutSize"] as? Int, 2)
        XCTAssertEqual(passthrough?["integerMaxOutput"] as? Int, Int(maxValue))
    }

    func testWriteProducesClipsterXML() throws {
        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.title = "Sample"
        lut.passthroughFileOptions = [LUTFormatterClipster.formatterIdentifier: ["lutSize": 2,
                                                                                 "integerMaxOutput": LUTMath.maxInteger(bitDepth: 10)]]

        let xml = try LUTFormatterClipster.write(lut)
        XCTAssertTrue(xml.contains("<LUT3D"))
        XCTAssertTrue(xml.contains("N='2'"))
        XCTAssertTrue(xml.contains("BitDepth='10'"))
        XCTAssertTrue(xml.contains("<values>"))
        XCTAssertTrue(xml.contains("0 0 0"))
    }

    func testWriteResizesWhenOptionsDemandDifferentSize() throws {
        let lut = LUT3D.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let xml = try LUTFormatterClipster.write(lut, options: .init(lutSize: 2, integerMaxOutput: LUTMath.maxInteger(bitDepth: 10)))
        XCTAssertTrue(xml.contains("N='2'"))
    }
}
