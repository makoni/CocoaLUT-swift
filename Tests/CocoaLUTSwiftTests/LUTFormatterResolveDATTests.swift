import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTFormatterResolveDATTests {
    @Test
    func testReadResolveDATParsesCube() throws {
        let source = """
        # Resolve DAT sample
        3DLUTSIZE 2

        0.0 0.0 0.0
        0.0 0.0 1.0
        0.0 1.0 0.0
        0.0 1.0 1.0
        1.0 0.0 0.0
        1.0 0.2 0.8
        1.0 1.0 0.0
        1.0 1.0 1.0
        """

        let lut = try LUTFormatterResolveDAT.read(string: source)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 0, g: 0, b: 0).red, 0.0, accuracy: 1e-9)
        XCTAssertEqual(lut.colorAt(r: 1, g: 0, b: 1).green, 0.2, accuracy: 1e-9)
        XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).blue, 1.0, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Resolve")
    }

    @Test
    func testReadResolveDATThrowsForIncompletePayload() {
        let source = """
        3DLUTSIZE 2
        0.0 0.0 0.0
        0.0 0.0 1.0
        """

        XCTAssertThrowsError(try LUTFormatterResolveDAT.read(string: source)) { error in
            guard case LUTFormatterResolveDATErrors.incompleteData(let expected, let found) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, 8)
            XCTAssertEqual(found, 2)
        }
    }

    @Test
    func testWriteResolveDATIncludesHeaderForNonDefaultSize() throws {
    let lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let output = try LUTFormatterResolveDAT.write(lut)
        XCTAssertTrue(output.hasPrefix("3DLUTSIZE 2"))
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 10)
        XCTAssertEqual(lines.last, "1.000000 1.000000 1.000000")
    }

    @Test
    func testWriteResolveDATOmitsHeaderForDefaultSize() throws {
    let lut = LUT3D.identity(size: 33, inputLowerBound: 0, inputUpperBound: 1)
        let output = try LUTFormatterResolveDAT.write(lut)
        XCTAssertFalse(output.contains("3DLUTSIZE"))
        XCTAssertTrue(output.hasPrefix("0.000000"))
        // spot check a late entry to ensure ordering is stable
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 33 * 33 * 33)
        XCTAssertEqual(lines.first, "0.000000 0.000000 0.000000")
    }

    @Test
    func testDaVinciFormatterUsesResolveImplementation() throws {
        let source = """
        3DLUTSIZE 2
        0.0 0.0 0.0
        1.0 1.0 1.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 1.0
        1.0 1.0 0.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        """

        let lut = try LUTFormatterDaVinciDAVLUT.read(string: source)
        XCTAssertEqual(lut.size, 2)
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "DaVinci")
    }
}
