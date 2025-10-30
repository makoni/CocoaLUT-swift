import Foundation
import XCTest
@testable import CocoaLUT_swift

final class CocoaLUTFacadeTests: XCTestCase {
    func testConstantsMirrorHelperValues() {
        XCTAssertEqual(CocoaLUT.suggestedMaxLUT1DSize, LUTConstants.suggestedMax1DSize)
        XCTAssertEqual(CocoaLUT.suggestedMaxLUT3DSize, LUTConstants.suggestedMax3DSize)
        XCTAssertEqual(CocoaLUT.maxCIColorCubeSize, LUTConstants.maxCIColorCubeSize)
        XCTAssertEqual(CocoaLUT.maxVVLUT1DFilterSize, LUTConstants.maxVVLUT1DFilterSize)
    }

    func testDescriptorLookupThrowsForUnknownIdentifier() {
        XCTAssertThrowsError(try CocoaLUT.descriptor(for: "does-not-exist")) { error in
            guard case CocoaLUT.Error.formatterNotFound(let identifier) = error else {
                XCTFail("Expected formatterNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(identifier, "does-not-exist")
        }
    }

    func testDescriptorsForUnknownExtensionAreEmpty() {
        XCTAssertTrue(CocoaLUT.descriptors(forFileExtension: "unknown").isEmpty)
    }

    func testReadWithoutDescriptorThrows() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("example.cube")
        XCTAssertThrowsError(try CocoaLUT.read(from: url)) { error in
            guard case CocoaLUT.Error.formatterNotFound(let identifier) = error else {
                XCTFail("Expected formatterNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(identifier, "cube")
        }
    }

    func testWriteWithoutDescriptorThrows() {
        let lut = LUT1D(redCurve: [0.0, 1.0],
                        greenCurve: [0.0, 1.0],
                        blueCurve: [0.0, 1.0],
                        inputLowerBound: 0.0,
                        inputUpperBound: 1.0)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("output.cube")

        XCTAssertThrowsError(try CocoaLUT.write(.lut1D(lut), to: url, formatterIdentifier: "cube")) { error in
            guard case CocoaLUT.Error.formatterNotFound(let identifier) = error else {
                XCTFail("Expected formatterNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(identifier, "cube")
        }
    }
}
