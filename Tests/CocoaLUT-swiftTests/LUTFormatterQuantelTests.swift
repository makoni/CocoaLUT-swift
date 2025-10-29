import XCTest
@testable import CocoaLUT_swift

final class LUTFormatterQuantelTests: XCTestCase {
    func testReadQuantelLUT() throws {
        let sample = """
        max value 1023
        vertices 2
        cube data
        R G B
        0 0 0
        0 0 1023
        0 1023 0
        0 1023 1023
        1023 0 0
        1023 0 1023
        1023 1023 0
        1023 1023 1023
        """

        let lut = try LUTFormatterQuantel.read(string: sample)
    XCTAssertEqual(lut.size, 2)
    XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).red, 1.0, accuracy: 1e-6)
    XCTAssertEqual(lut.colorAt(r: 0, g: 1, b: 0).green, 1.0, accuracy: 1e-6)
    let passthrough = lut.passthroughFileOptions["quantel"] as? [String: Any]
    XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Quantel")
    XCTAssertEqual(passthrough?["integerMaxOutput"] as? Int, 1023)
    XCTAssertEqual(passthrough?["lutSize"] as? Int, 2)
    }

    func testWriteQuantelLUT() throws {
        var lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<2 {
            for g in 0..<2 {
                for b in 0..<2 {
                    let color = LUTColor.color(red: Double(r), green: Double(g), blue: Double(b))
                    lut.setColor(color, r: r, g: g, b: b)
                }
            }
        }

        let string = try LUTFormatterQuantel.write(lut, options: .init(integerMaxOutput: 1023, lutSize: 2))
        XCTAssertTrue(string.contains("max value 1023"))
        XCTAssertTrue(string.contains("vertices 2"))
    }
}
