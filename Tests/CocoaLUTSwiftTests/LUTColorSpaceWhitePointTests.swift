import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTColorSpaceWhitePointTests {
    @Test
    func testTristimulusValuesMatchReference() {
        let d65 = LUTColorSpaceWhitePoint.d65.tristimulusValues
        #expect(abs(d65.x - 0.95043) < 1e-4)
        #expect(abs(d65.y - 1.0) < 1e-4)
        #expect(abs(d65.z - 1.08890) < 1e-4)
    }

    @Test
    func testColorTemperatureWithinSupportedRangeProducesExpectedChromaticity() {
        guard let tungsten = LUTColorSpaceWhitePoint.fromColorTemperature(3200) else {
            Issue.record("Expected 3200K to be supported")
            return
        }

        #expect(abs(tungsten.whiteChromaticityX - 0.42318) < 1e-4)
        #expect(abs(tungsten.whiteChromaticityY - 0.39908) < 5e-5)
        #expect(tungsten.name == "3200K")
    }

    @Test
    func testCustomNameOverridePreservedForKnownColorTemperature() {
        guard let custom = LUTColorSpaceWhitePoint.fromColorTemperature(5600, customName: "Daylight") else {
            Issue.record("Expected 5600K to be supported")
            return
        }

        #expect(custom.name == "Daylight")
    }

    @Test
    func testColorTemperatureOutsideRangeReturnsNil() {
        #expect(LUTColorSpaceWhitePoint.fromColorTemperature(1000) == nil)
        #expect(LUTColorSpaceWhitePoint.fromColorTemperature(50000) == nil)
    }
}
