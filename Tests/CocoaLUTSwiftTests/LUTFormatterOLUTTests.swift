import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTFormatterOLUTTests {
    @Test
    func testReadParsesCurves() throws {
        let payload = "0,2048,4095,0,2048,4095\n1024,3072,0,1024,3072,0\n"
        let lut = try LUTFormatterOLUT.read(string: payload)

        #expect(lut.size == 2)
        #expect(lut.valueAtR(0) == 0)
        #expect(abs(lut.valueAtG(0) - (2048.0 / 4095.0)) < 1e-6)
        #expect(abs(lut.valueAtB(0) - 1) < 1e-6)

        #expect(abs(lut.valueAtR(1) - (1024.0 / 4095.0)) < 1e-6)
        #expect(abs(lut.valueAtG(1) - (3072.0 / 4095.0)) < 1e-6)
        #expect(abs(lut.valueAtB(1) - 0) < 1e-6)

        let passthrough = lut.passthroughFileOptions[LUTFormatterOLUT.formatterIdentifier] as? [String: Any]
        #expect(passthrough?["lutSize"] as? Int == 2)
        #expect(passthrough?["fileTypeVariant"] as? String == "OLUT")
    }

    @Test
    func testWriteProducesExpectedCSV() throws {
        var lut = LUT1D(redCurve: [0, 0.25, 0.5],
                        greenCurve: [0, 0.5, 1],
                        blueCurve: [1, 0.5, 0],
                        inputLowerBound: 0,
                        inputUpperBound: 1)
        lut.passthroughFileOptions = [LUTFormatterOLUT.formatterIdentifier: ["lutSize": 3]]

        let output = try LUTFormatterOLUT.write(lut)
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "0,0,4095,0,0,4095")
        #expect(lines[1] == "1023,2047,2047,1023,2047,2047")
        #expect(lines[2] == "2047,4095,0,2047,4095,0")
    }

    @Test
    func testWriteResizesWhenNeeded() throws {
        let lut = LUT1D(redCurve: [0, 1],
                        greenCurve: [0, 1],
                        blueCurve: [0, 1],
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let output = try LUTFormatterOLUT.write(lut, options: .init(lutSize: 4))
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines.first == "0,0,0,0,0,0")
        #expect(lines.last == "4095,4095,4095,4095,4095,4095")
    }
}
