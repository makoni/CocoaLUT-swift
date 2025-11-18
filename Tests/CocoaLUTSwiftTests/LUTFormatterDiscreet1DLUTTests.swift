import XCTest
@testable import CocoaLUTSwift

final class LUTFormatterDiscreet1DLUTTests: XCTestCase {
    func testReadDiscreet1DLUT() throws {
        let source = """
        # Example Discreet LUT
        Scale: 4095
        LUT: 3 4
        0
        1365
        2730
        4095
        0
        2047
        3071
        4095
        0
        1023
        3071
        4095
        """

        let lut = try LUTFormatterDiscreet1DLUT.read(string: source)
        XCTAssertEqual(lut.size, 4)
        XCTAssertEqual(lut.valueAtR(1), 1365.0 / 4095.0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtG(2), 3071.0 / 4095.0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtB(1), 1023.0 / 4095.0, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterDiscreet1DLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["integerMaxOutput"] as? Int, 4095)
        XCTAssertEqual(passthrough?["lutSize"] as? Int, 4)
    }

    func testWriteDiscreet1DLUT() throws {
        let lut = LUT1D.uniformCurve(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let output = try LUTFormatterDiscreet1DLUT.write(lut, options: .init(integerMaxOutput: 1023))
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "#")
        XCTAssertEqual(lines[6], "# Exported from CocoaLUT")
        XCTAssertEqual(lines[7], "#")
        XCTAssertEqual(lines[8], "LUT: 3 4")
        XCTAssertEqual(lines.count, 9 + 12) // header + 3 * size lines
        XCTAssertEqual(lines.last, "1023")
    }
}
