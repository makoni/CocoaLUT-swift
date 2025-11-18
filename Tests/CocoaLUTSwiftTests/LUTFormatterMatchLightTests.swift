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
        #expect(lut.size == 2)
        #expect(abs(lut.colorAt(r: 1, g: 0, b: 1).red - 1) <= 1e-6)
        #expect(abs(lut.colorAt(r: 0, g: 1, b: 0).green - 1) <= 1e-6)

        let passthrough = lut.passthroughFileOptions[LUTFormatterMatchLight.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["fileTypeVariant"] as? String == "MatchLight")
        #expect(passthrough?["lut1DSize"] as? Int == 2)
        #expect(passthrough?["lut3DSize"] as? Int == 2)
    }

    @Test
    func testThrowsWhenDataMissing() {
        do {
            _ = try LUTFormatterMatchLight.read(string: "# no data")
            Issue.record(Comment("Expected LUTFormatterMatchLightError.missingLUTData"))
        } catch {
            if case LUTFormatterMatchLightError.missingLUTData = error {
                // Success
            } else {
                Issue.record(Comment("Unexpected error \(error)"))
            }
        }
    }
}
