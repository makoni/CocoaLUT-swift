import XCTest
@testable import CocoaLUT_swift

final class LUTColorSpaceWhitePointTests: XCTestCase {
    func testTristimulusValuesMatchReference() {
        let d65 = LUTColorSpaceWhitePoint.d65.tristimulusValues
    XCTAssertEqual(d65.x, 0.95043, accuracy: 1e-4)
    XCTAssertEqual(d65.y, 1.0, accuracy: 1e-4)
    XCTAssertEqual(d65.z, 1.08890, accuracy: 1e-4)
    }

    func testColorTemperatureWithinSupportedRangeProducesExpectedChromaticity() {
        guard let tungsten = LUTColorSpaceWhitePoint.fromColorTemperature(3200) else {
            XCTFail("Expected 3200K to be supported")
            return
        }

    XCTAssertEqual(tungsten.whiteChromaticityX, 0.42318, accuracy: 1e-4)
    XCTAssertEqual(tungsten.whiteChromaticityY, 0.39908, accuracy: 5e-5)
        XCTAssertEqual(tungsten.name, "3200K")
    }

    func testCustomNameOverridePreservedForKnownColorTemperature() {
        guard let custom = LUTColorSpaceWhitePoint.fromColorTemperature(5600, customName: "Daylight") else {
            XCTFail("Expected 5600K to be supported")
            return
        }

        XCTAssertEqual(custom.name, "Daylight")
    }

    func testColorTemperatureOutsideRangeReturnsNil() {
        XCTAssertNil(LUTColorSpaceWhitePoint.fromColorTemperature(1000))
        XCTAssertNil(LUTColorSpaceWhitePoint.fromColorTemperature(50000))
    }
}
