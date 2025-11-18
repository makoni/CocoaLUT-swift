import XCTest
@testable import CocoaLUTSwift

final class LUTFormatterOLUTTests: XCTestCase {
    func testReadParsesCurves() throws {
        let payload = "0,2048,4095,0,2048,4095\n1024,3072,0,1024,3072,0\n"
        let lut = try LUTFormatterOLUT.read(string: payload)

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.valueAtR(0), 0)
    XCTAssertEqual(lut.valueAtG(0), 2048.0 / 4095.0, accuracy: 1e-6)
        XCTAssertEqual(lut.valueAtB(0), 1, accuracy: 1e-6)

        XCTAssertEqual(lut.valueAtR(1), 1024.0 / 4095.0, accuracy: 1e-6)
        XCTAssertEqual(lut.valueAtG(1), 3072.0 / 4095.0, accuracy: 1e-6)
        XCTAssertEqual(lut.valueAtB(1), 0, accuracy: 1e-6)

        let passthrough = lut.passthroughFileOptions[LUTFormatterOLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["lutSize"] as? Int, 2)
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "OLUT")
    }

    func testWriteProducesExpectedCSV() throws {
        var lut = LUT1D(redCurve: [0, 0.25, 0.5],
                        greenCurve: [0, 0.5, 1],
                        blueCurve: [1, 0.5, 0],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        lut.passthroughFileOptions = [LUTFormatterOLUT.formatterIdentifier: ["lutSize": 3]]

        let output = try LUTFormatterOLUT.write(lut)
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "0,0,4095,0,0,4095")
        XCTAssertEqual(lines[1], "1023,2047,2047,1023,2047,2047")
        XCTAssertEqual(lines[2], "2047,4095,0,2047,4095,0")
    }

    func testWriteResizesWhenNeeded() throws {
        let lut = LUT1D(redCurve: [0, 1],
                        greenCurve: [0, 1],
                        blueCurve: [0, 1],
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let output = try LUTFormatterOLUT.write(lut, options: .init(lutSize: 4))
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines.first, "0,0,0,0,0,0")
        XCTAssertEqual(lines.last, "4095,4095,4095,4095,4095,4095")
    }
}
