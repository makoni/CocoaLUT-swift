#if canImport(AppKit)
import AppKit
import XCTest
@testable import CocoaLUTSwift

@MainActor
final class LUTFormatterICCProfileTests: XCTestCase {
    func testReadGenericRGBProfileProducesIdentityTransform() throws {
        let colorSpace = NSColorSpace.genericRGB
        let data = try XCTUnwrap(colorSpace.iccProfileData)
        let lut = try LUTFormatterICCProfile.read(data: data, size: 17)

        XCTAssertEqual(lut.size, 17)
        let reference = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let sampleIndices = [0, 8, 16]
        for r in sampleIndices {
            for g in sampleIndices {
                for b in sampleIndices {
                    let transformed = lut.colorAt(r: r, g: g, b: b)
                    let expected = reference.colorAt(r: r, g: g, b: b)
                    XCTAssertEqual(transformed.red, expected.red, accuracy: 1e-6, "Red mismatch at (\(r),\(g),\(b))")
                    XCTAssertEqual(transformed.green, expected.green, accuracy: 1e-6, "Green mismatch at (\(r),\(g),\(b))")
                    XCTAssertEqual(transformed.blue, expected.blue, accuracy: 1e-6, "Blue mismatch at (\(r),\(g),\(b))")
                }
            }
        }

        let passthrough = lut.passthroughFileOptions[LUTFormatterICCProfile.formatterIdentifier] as? [String: Any]
        XCTAssertNotNil(passthrough)
        XCTAssertTrue(passthrough?.isEmpty ?? false)
    }

    func testReadFromURLMatchesDataPath() throws {
        let colorSpace = NSColorSpace.genericRGB
        let data = try XCTUnwrap(colorSpace.iccProfileData)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("icc")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let lut = try LUTFormatterICCProfile.read(url: tempURL, size: 9)
        XCTAssertEqual(lut.size, 9)
    }

    func testUnsupportedComponentCountThrows() throws {
        let colorSpace = NSColorSpace.genericCMYK
        let data = try XCTUnwrap(colorSpace.iccProfileData)

        XCTAssertThrowsError(try LUTFormatterICCProfile.read(data: data)) { error in
            XCTAssertEqual(error as? LUTFormatterICCProfileError, .unsupportedComponentCount(4))
        }
    }

    func testInvalidDataThrows() {
        let data = Data(repeating: 0xAA, count: 32)
        XCTAssertThrowsError(try LUTFormatterICCProfile.read(data: data)) { error in
            XCTAssertEqual(error as? LUTFormatterICCProfileError, .invalidProfile)
        }
    }
}
#endif
