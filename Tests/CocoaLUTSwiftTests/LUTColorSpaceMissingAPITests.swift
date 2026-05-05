import Testing
@testable import CocoaLUTSwift
import simd

struct LUTColorSpaceMissingAPITests {

    @Test func testNPM() throws {
        let space = LUTColorSpace.rec709
        let whitePoint = LUTColorSpaceWhitePoint(whiteChromaticityX: 0.3127, whiteChromaticityY: 0.3290, name: "D65")
        let matrix = try space.npm(using: whitePoint)
        // Just check it returns a matrix
        #expect(matrix.columns.0.x > 0)
    }

    @Test func testForcedNPM() {
        let matrix = simd_double3x3(1)
        let space = LUTColorSpace.forcedNPM(matrix, name: "Test")
        #expect(space.forcedNPMMatrix != nil)
        #expect(space.forcesNPM)
    }
}
