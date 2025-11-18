import XCTest
@testable import CocoaLUTSwift

final class LUTFormatterILUTTests: XCTestCase {
    func testReadILUTStringParsesCurves() throws {
    let fixture = """
    0,0,0,0
    8192,4096,2048,0
    16383,16383,8192,0
    """

        let lut = try LUTFormatterILUT.read(string: fixture)
        XCTAssertEqual(lut.size, 3)
        XCTAssertEqual(lut.valueAtR(0), 0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtG(1), 4096.0 / 16383.0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtB(2), 8192.0 / 16383.0, accuracy: 1e-9)
        XCTAssertEqual(lut.passthroughFileOptions.keys.first, LUTFormatterILUT.formatterIdentifier)
    }

    func testWriteProducesExpectedILUTContents() throws {
        let lut = LUT1D.uniformCurve(size: 16384,
                                    inputLowerBound: 0,
                                    inputUpperBound: 1)

        let output = try LUTFormatterILUT.write(lut)
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 16384)
        XCTAssertEqual(lines.first, "0,0,0,0")
        XCTAssertEqual(lines.last, "16383,16383,16383,0")
    }

    func testWriteResizesSmallerLUT() throws {
        let lut = LUT1D.uniformCurve(size: 16,
                                    inputLowerBound: 0,
                                    inputUpperBound: 1)

        let output = try LUTFormatterILUT.write(lut)
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 16384)
        XCTAssertEqual(lines.first, "0,0,0,0")
        XCTAssertEqual(lines.last, "16383,16383,16383,0")
    }
}
