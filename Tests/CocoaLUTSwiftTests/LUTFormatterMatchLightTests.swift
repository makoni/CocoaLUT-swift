import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTFormatterMatchLightTests {
    @Test
    func testReadCombines1DAnd3DLUT() throws {
        let source = """
        # MatchLight Example
        lutS 0 2
        cubeS 0 2
        0 0 0
        1 1 1
        # CUBE
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """

        let lut = try LUTFormatterMatchLight.read(string: source)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 1, g: 0, b: 1).red, 1, accuracy: 1e-6)
        XCTAssertEqual(lut.colorAt(r: 0, g: 1, b: 0).green, 1, accuracy: 1e-6)

        let passthrough = lut.passthroughFileOptions[LUTFormatterMatchLight.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "MatchLight")
        XCTAssertEqual(passthrough?["lut1DSize"] as? Int, 2)
        XCTAssertEqual(passthrough?["lut3DSize"] as? Int, 2)
    }

    @Test
    func testThrowsWhenDataMissing() {
        XCTAssertThrowsError(try LUTFormatterMatchLight.read(string: "# no data")) { error in
            guard case LUTFormatterMatchLightError.missingLUTData = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }
}
