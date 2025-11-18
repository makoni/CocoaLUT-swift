import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTFormatter3DLTests {
    @Test
    func testReadNuke3DL() throws {
        let contents = """
        # Sample 3DL
        0 4095

        0 0 0
        0 0 4095
        0 4095 0
        0 4095 4095
        4095 0 0
        4095 0 4095
        4095 4095 0
        4095 4095 4095
        """

        let lut = try LUTFormatter3DL.read(string: contents)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.inputLowerBound, 0)
        XCTAssertEqual(lut.inputUpperBound, 1)
        XCTAssertEqual(lut.colorAt(r: 1, g: 0, b: 0), LUTColor.color(red: 1, green: 0, blue: 0))
        XCTAssertEqual(lut.colorAt(r: 0, g: 1, b: 1), LUTColor.color(red: 0, green: 1, blue: 1))

        let passthrough = lut.passthroughFileOptions[LUTFormatter3DL.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthroughVariant(passthrough), LUTFormatter3DL.Variant.nuke.rawValue)
        XCTAssertEqual(passthroughIntegerMax(passthrough), 4095)
        XCTAssertEqual(passthroughLUTSize(passthrough), 2)
    }

    @Test
    func testRoundTripWriteRead3DL() throws {
        let contents = """
        0 4095

        0 0 0
        0 0 4095
        0 4095 0
        0 4095 4095
        4095 0 0
        4095 0 4095
        4095 4095 0
        4095 4095 4095
        """

        let original = try LUTFormatter3DL.read(string: contents)
        let serialized = try LUTFormatter3DL.write(original)
        let roundTrip = try LUTFormatter3DL.read(string: serialized)

        XCTAssertEqual(roundTrip.size, original.size)
        for r in 0..<original.size {
            for g in 0..<original.size {
                for b in 0..<original.size {
                    XCTAssertEqual(roundTrip.colorAt(r: r, g: g, b: b),
                                   original.colorAt(r: r, g: g, b: b),
                                   "Mismatch at r: \(r) g: \(g) b: \(b)")
                }
            }
        }
    }

    @Test
    func testWriteLegacyVariantProducesLegacyHeader() throws {
        var lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut.passthroughFileOptions = [:]

        let options = LUTFormatter3DL.Options(variant: .legacy, integerMaxOutput: LUTMath.maxInteger(bitDepth: 12))
        let serialized = try LUTFormatter3DL.write(lut, options: options)

        XCTAssertTrue(serialized.contains("0 1023"))

        let reread = try LUTFormatter3DL.read(string: serialized)
        let passthrough = reread.passthroughFileOptions[LUTFormatter3DL.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthroughVariant(passthrough), LUTFormatter3DL.Variant.legacy.rawValue)
    }

    private func passthroughVariant(_ options: [String: Any]?) -> String? {
        options?["fileTypeVariant"] as? String
    }

    private func passthroughIntegerMax(_ options: [String: Any]?) -> Int? {
        if let value = options?["integerMaxOutput"] as? Int {
            return value
        }
        if let number = options?["integerMaxOutput"] as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func passthroughLUTSize(_ options: [String: Any]?) -> Int? {
        if let value = options?["lutSize"] as? Int {
            return value
        }
        if let number = options?["lutSize"] as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
