import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTFormatterILUTTests {
    @Test
    func testReadILUTStringParsesCurves() throws {
    let fixture = """
    0,0,0,0
    8192,4096,2048,0
    16383,16383,8192,0
    """

        let lut = try LUTFormatterILUT.read(string: fixture)
        #expect(lut.size == 3)
        #expect(abs(lut.valueAtR(0) - 0) < 1e-9)
        #expect(abs(lut.valueAtG(1) - (4096.0 / 16383.0)) < 1e-9)
        #expect(abs(lut.valueAtB(2) - (8192.0 / 16383.0)) < 1e-9)
        #expect(lut.passthroughFileOptions.keys.first == LUTFormatterILUT.formatterIdentifier)
    }

    @Test
    func testWriteProducesExpectedILUTContents() throws {
        let lut = LUT1D.uniformCurve(size: 16384,
                                    inputLowerBound: 0,
                                    inputUpperBound: 1)

        let output = try LUTFormatterILUT.write(lut)
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 16384)
        #expect(lines.first == "0,0,0,0")
        #expect(lines.last == "16383,16383,16383,0")
    }

    @Test
    func testWriteResizesSmallerLUT() throws {
        let lut = LUT1D.uniformCurve(size: 16,
                                    inputLowerBound: 0,
                                    inputUpperBound: 1)

        let output = try LUTFormatterILUT.write(lut)
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 16384)
        #expect(lines.first == "0,0,0,0")
        #expect(lines.last == "16383,16383,16383,0")
    }
}
