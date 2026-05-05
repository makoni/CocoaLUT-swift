import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTFormatterDiscreet1DLUTTests {
    @Test
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
        #expect(lut.size == 4)
        #expect(abs(lut.valueAtR(1) - (1365.0 / 4095.0)) <= 1e-9)
        #expect(abs(lut.valueAtG(2) - (3071.0 / 4095.0)) <= 1e-9)
        #expect(abs(lut.valueAtB(1) - (1023.0 / 4095.0)) <= 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterDiscreet1DLUT.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["integerMaxOutput"] as? Int == 4095)
        #expect(passthrough?["lutSize"] as? Int == 4)
    }

    @Test
    func testWriteDiscreet1DLUT() throws {
        let lut = LUT1D.uniformCurve(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let output = try LUTFormatterDiscreet1DLUT.write(lut, options: .init(integerMaxOutput: 1023))
        let lines = output.components(separatedBy: "\n")
        #expect(lines[0] == "#")
        #expect(lines[6] == "# Exported from CocoaLUT")
        #expect(lines[7] == "#")
        #expect(lines[8] == "LUT: 3 4")
        #expect(lines.count == 9 + 12) // header + 3 * size lines
        #expect(lines.last == "1023")
    }
}
