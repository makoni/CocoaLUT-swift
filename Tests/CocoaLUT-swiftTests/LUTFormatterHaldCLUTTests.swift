import XCTest
#if canImport(AppKit)
import AppKit
#endif
@testable import CocoaLUTSwift

final class LUTFormatterHaldCLUTTests: XCTestCase {
    func testEightBitRoundTrip() throws {
        let lut = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let image = try LUTFormatterHaldCLUT.image(from: lut)
        let decoded = try LUTFormatterHaldCLUT.read(image: image)
        XCTAssertTrue(decoded.equals(lut, tolerance: 1e-6))
    }

    func testSixteenBitRoundTrip() throws {
        let lut = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)
        let image = try LUTFormatterHaldCLUT.image(from: lut, options: .init(bitDepth: 16))
        let decoded = try LUTFormatterHaldCLUT.read(image: image)
        XCTAssertTrue(decoded.equals(lut, tolerance: 1e-6))
    }

    func testPNGEncodingProducesData() throws {
        let lut = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let data = try LUTFormatterHaldCLUT.pngData(from: lut)
        XCTAssertFalse(data.isEmpty)
    }

    #if canImport(AppKit)
    func testNSImageRoundTrip() throws {
        let lut = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let image = try LUTFormatterHaldCLUT.nsImage(from: lut)
        let decoded = try LUTFormatterHaldCLUT.read(nsImage: image)
        XCTAssertTrue(decoded.equals(lut, tolerance: 1e-6))
    }
    #endif
}
