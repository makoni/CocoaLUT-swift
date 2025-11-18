import XCTest
@testable import CocoaLUTSwift

final class LUTFormatterFSIDATTests: XCTestCase {
    func testVariantV2RoundTripPreservesMetadata() throws {
        var lut = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        lut.title = "Sample"
        lut.descriptionText = "Identity LUT"
        lut.metadata = ["version": "1.0", "model": "XM55"]

        let data = try LUTFormatterFSIDAT.write(lut, options: .init(variant: .v2))
        let decoded = try LUTFormatterFSIDAT.read(data: data)

        XCTAssertTrue(decoded.equals(lut, tolerance: 1e-6))
        XCTAssertEqual(decoded.title, "Sample")
        XCTAssertEqual(decoded.descriptionText, "Identity LUT")
        XCTAssertEqual(decoded.metadata["version"] as? String, "1.0")
        XCTAssertEqual(decoded.metadata["model"] as? String, "XM55")
        let passthrough = decoded.passthroughFileOptions["fsiDAT"] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "v2")
        XCTAssertEqual(passthrough?["lutSize"] as? Int, 17)
    }

    func testVariantV1RoundTrip() throws {
        let lut = LUT3D.identity(size: 64, inputLowerBound: 0, inputUpperBound: 1)
        let data = try LUTFormatterFSIDAT.write(lut, options: .init(variant: .v1))
        let decoded = try LUTFormatterFSIDAT.read(data: data)
        XCTAssertTrue(decoded.equals(lut, tolerance: 1e-6))
    }

    func testWriteThrowsForMismatchedSize() throws {
        let lut = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        XCTAssertThrowsError(try LUTFormatterFSIDAT.write(lut, options: .init(variant: .v1))) { error in
            guard case let LUTFormatterFSIDATError.invalidLUTSize(expected, actual) = error else {
                XCTFail("Unexpected error type: \(error)")
                return
            }
            XCTAssertEqual(expected, 64)
            XCTAssertEqual(actual, 17)
        }
    }

    func testReadRejectsInvalidFile() {
        let data = Data(count: 64)
        XCTAssertThrowsError(try LUTFormatterFSIDAT.read(data: data))
    }
}
