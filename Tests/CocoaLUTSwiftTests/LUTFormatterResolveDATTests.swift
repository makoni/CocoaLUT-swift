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
        #expect(lut.size == 2)
        #expect(abs(lut.colorAt(r: 0, g: 0, b: 0).red - 0.0) < 1e-9)
        #expect(abs(lut.colorAt(r: 1, g: 0, b: 1).green - 0.2) < 1e-9)
        #expect(abs(lut.colorAt(r: 1, g: 1, b: 1).blue - 1.0) < 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["fileTypeVariant"] as? String == "Resolve")
    }

    @Test
    func testReadResolveDATThrowsForIncompletePayload() {
        let source = """
        3DLUTSIZE 2
        0.0 0.0 0.0
        0.0 0.0 1.0
        """

        #expect {
            try LUTFormatterResolveDAT.read(string: source)
        } throws: { error in
            guard case LUTFormatterResolveDATErrors.incompleteData(let expected, let found) = error else {
                return false
            }
            return expected == 8 && found == 2
        }
    }

    @Test
    func testWriteResolveDATIncludesHeaderForNonDefaultSize() throws {
    let lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let output = try LUTFormatterResolveDAT.write(lut)
        #expect(output.hasPrefix("3DLUTSIZE 2"))
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 10)
        #expect(lines.last == "1.000000 1.000000 1.000000")
    }

    @Test
    func testWriteResolveDATOmitsHeaderForDefaultSize() throws {
    let lut = LUT3D.identity(size: 33, inputLowerBound: 0, inputUpperBound: 1)
        let output = try LUTFormatterResolveDAT.write(lut)
        #expect(!output.contains("3DLUTSIZE"))
        #expect(output.hasPrefix("0.000000"))
        // spot check a late entry to ensure ordering is stable
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 33 * 33 * 33)
        #expect(lines.first == "0.000000 0.000000 0.000000")
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
        #expect(lut.size == 2)
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["fileTypeVariant"] as? String == "DaVinci")
    }
}
