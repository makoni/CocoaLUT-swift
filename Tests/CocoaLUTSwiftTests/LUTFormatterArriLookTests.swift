import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTFormatterArriLookTests {
    @Test
    func testReadAppliesSaturationPrinterLightsToneMapAndSOP() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <adicam version="1.0" camera="alexa">
            <Saturation>
                1.250000
            </Saturation>
            <PrinterLight>
                0.100000 0.050000 -0.025000
            </PrinterLight>
            <SOPNode>
                <Slope>1.050000 0.950000 1.100000</Slope>
                <Offset>0.010000 0.020000 -0.015000</Offset>
                <Power>0.900000 1.050000 1.100000</Power>
            </SOPNode>
            <ToneMapLut rows="4" cols="1">
                0
                1365
                2731
                4095
            </ToneMapLut>
        </adicam>
        """

        let lut = try LUTFormatterArriLook.read(string: xml)
        XCTAssertEqual(lut.size, 33)
        let passthrough = lut.passthroughFileOptions[LUTFormatterArriLook.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Arri")
        XCTAssertEqual(passthrough?["lutSize"] as? Int, 4)

        let sampleIndices = (r: 16, g: 8, b: 24)
        let resultColor = lut.colorAt(r: sampleIndices.r, g: sampleIndices.g, b: sampleIndices.b)

        let baseColor = LUTColor.color(red: Double(sampleIndices.r) / 32.0,
                                       green: Double(sampleIndices.g) / 32.0,
                                       blue: Double(sampleIndices.b) / 32.0)

        let toneMapCurve = [0.0, 1365.0 / 4095.0, 2731.0 / 4095.0, 1.0]
        let toneMap = LUT1D(redCurve: toneMapCurve,
                            greenCurve: toneMapCurve,
                            blueCurve: toneMapCurve,
                            inputLowerBound: 0,
                            inputUpperBound: 1)
        let printerLight = LUTColor.color(red: 0.1, green: 0.05, blue: -0.025)

        var expected = baseColor.changingSaturation(1.25,
                                                    lumaR: 0.291948669899,
                                                    lumaG: 0.823830265984,
                                                    lumaB: -0.115778935883)
        expected = expected.adding(printerLight)
        expected = toneMap.color(at: expected)
        expected = expected.applyingSlopeOffsetPower(redSlope: 1.05,
                                                     redOffset: 0.01,
                                                     redPower: 0.9,
                                                     greenSlope: 0.95,
                                                     greenOffset: 0.02,
                                                     greenPower: 1.05,
                                                     blueSlope: 1.1,
                                                     blueOffset: -0.015,
                                                     bluePower: 1.1)

        XCTAssertEqual(resultColor.red, expected.red, accuracy: 1e-6)
        XCTAssertEqual(resultColor.green, expected.green, accuracy: 1e-6)
        XCTAssertEqual(resultColor.blue, expected.blue, accuracy: 1e-6)
    }

    @Test
    func testWriteProducesExpectedToneMapSection() throws {
        let curve = stride(from: 0, to: 4, by: 1).map { Double($0) / 3.0 }
        let lut = LUT1D(redCurve: curve,
                        greenCurve: curve,
                        blueCurve: curve,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        let output = try LUTFormatterArriLook.write(lut, options: .init(lutSize: 4))
        XCTAssertTrue(output.contains("<ToneMapLut rows=\"4\" cols=\"1\">"))
        let lines = output.components(separatedBy: "\n")
        XCTAssertTrue(lines.contains("\t0"))
        XCTAssertTrue(lines.contains("\t1365"))
    XCTAssertTrue(lines.contains("\t2730"))
        XCTAssertTrue(lines.contains("\t4095"))
        XCTAssertTrue(output.hasSuffix("</adicam>"))
    }
}
