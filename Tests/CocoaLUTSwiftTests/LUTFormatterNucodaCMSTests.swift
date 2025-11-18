import XCTest
@testable import CocoaLUTSwift

final class LUTFormatterNucodaCMSTests: XCTestCase {
    func testReadCombinedVersion3() throws {
        let dataLines = [
            "0.0 0.0 0.0",
            "1.0 1.0 1.0",
            "0.0 0.0 0.0",
            "0.5 0.0 0.0",
            "0.0 0.5 0.0",
            "0.5 0.5 0.0",
            "0.0 0.0 0.5",
            "0.5 0.0 0.5",
            "0.0 0.5 0.5",
            "0.5 0.5 0.5"
        ].joined(separator: "\n")

        let sample = """
        NUCODA_3D_CUBE 3
        LUT_1D_SIZE 2
        LUT_1D_INPUT_RANGE 0.0 1.0
        LUT_3D_SIZE 2
        LUT_3D_INPUT_RANGE 0.0 1.0
        \(dataLines)
        """

        let result = try LUTFormatterNucodaCMS.read(string: sample)
        guard case .lut3D(let lut) = result else {
            XCTFail("Expected a 3D LUT result")
            return
        }

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).red, 0.5, accuracy: 1e-6)
        let passthrough = lut.passthroughFileOptions["nucoda"] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Nucoda v3")
        XCTAssertEqual(passthrough?["lutType"] as? String, "Pre-LUT and LUT")
    }

    func testReadCombinedVersion1NormalizesPreLUT() throws {
        let sample = """
        NUCODA_3D_CUBE 1
        LUT_1D_SIZE 2
        LUT_3D_SIZE 2
        0 0 0
        2 2 2
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """

        let result = try LUTFormatterNucodaCMS.read(string: sample)
        guard case .lut3D(let lut) = result else {
            XCTFail("Expected a 3D LUT result")
            return
        }

        XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).red, 1.0, accuracy: 1e-6)
        let passthrough = lut.passthroughFileOptions["nucoda"] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Nucoda v1")
    }

    func testReadOneDOnly() throws {
        let sample = """
        NUCODA_3D_CUBE 3
        LUT_1D_SIZE 2
        LUT_1D_INPUT_RANGE 0.0 1.0
        0.0 0.0 0.0
        1.0 1.0 1.0
        """

        let result = try LUTFormatterNucodaCMS.read(string: sample)
        guard case .lut1D(let lut) = result else {
            XCTFail("Expected a 1D LUT result")
            return
        }

        XCTAssertEqual(lut.size, 2)
        let passthrough = lut.passthroughFileOptions["nucoda"] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Nucoda v3")
        XCTAssertEqual(passthrough?["lutType"] as? String, "No Pre-LUT")
    }

    func testWriteThreeDRespectsPassthroughVariant() throws {
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    let color = LUTColor.color(red: Double(r) * 0.5,
                                                green: Double(g) * 0.5,
                                                blue: Double(b) * 0.5)
                    lut.setColor(color, r: r, g: g, b: b)
                }
            }
        }
        lut.passthroughFileOptions = ["nucoda": ["fileTypeVariant": "Nucoda v2"]]

        let output = try LUTFormatterNucodaCMS.write(.lut3D(lut))
        XCTAssertTrue(output.contains("NUCODA_3D_CUBE 2"))
        XCTAssertTrue(output.contains("LUT_3D_SIZE 2"))
        XCTAssertTrue(output.contains("LUT_3D_INPUT_RANGE 0.000 1.000"))
    }

    func testWriteOneDDefaultsToVersion3() throws {
        var lut = LUT1D.uniformCurve(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(LUTColor.color(red: 0.0, green: 0.0, blue: 0.0), index: 0)
        lut.setColor(LUTColor.color(red: 1.0, green: 1.0, blue: 1.0), index: 1)

        let output = try LUTFormatterNucodaCMS.write(.lut1D(lut))
        XCTAssertTrue(output.contains("NUCODA_3D_CUBE 3"))
        XCTAssertTrue(output.contains("LUT_1D_SIZE 2"))
        XCTAssertTrue(output.contains("LUT_1D_INPUT_RANGE 0.000 1.000"))
        XCTAssertTrue(output.contains("0.000000  0.000000  0.000000"))
        XCTAssertTrue(output.contains("1.000000  1.000000  1.000000"))
    }
}
