import Foundation
import XCTest
@testable import CocoaLUT_swift

final class LUTCubeFormatterTests: XCTestCase {
    func testReadLinearToBMDFilmCube() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "TestLinearToBMDFilm",
            withExtension: "cube",
            subdirectory: nil
        ))

        let result = try LUTCubeFormatter.read(url: url)
        guard case let .lut1D(lut) = result else {
            XCTFail("Expected to load a 1D LUT from cube file")
            return
        }

    XCTAssertEqual(lut.size, 16)
        XCTAssertEqual(lut.inputLowerBound, -0.0071215555, accuracy: 1e-9)
        XCTAssertEqual(lut.inputUpperBound, 5.7661304310, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtR(0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtR(1), 0.0070058769, accuracy: 1e-9)

        let passthrough = lut.passthroughFileOptions[LUTCubeFormatter.formatterIdentifier] as? [String: String]
    XCTAssertEqual(passthrough?["fileTypeVariant"], LUTCubeVariant.resolve.rawValue)
    }

    func testRoundTripWriteRead1D() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "TestLinearToBMDFilm",
            withExtension: "cube",
            subdirectory: nil
        ))

        let originalResult = try LUTCubeFormatter.read(url: url)
        guard case let .lut1D(original) = originalResult else {
            XCTFail("Expected a 1D LUT")
            return
        }

        let serialized = try LUTCubeFormatter.write(.lut1D(original))
        let roundTripResult = try LUTCubeFormatter.read(string: serialized)
        guard case let .lut1D(roundTrip) = roundTripResult else {
            XCTFail("Expected a 1D LUT from serialized data")
            return
        }

        XCTAssertEqual(roundTrip.size, original.size)
        XCTAssertEqual(roundTrip.inputLowerBound, original.inputLowerBound, accuracy: 1e-9)
        XCTAssertEqual(roundTrip.inputUpperBound, original.inputUpperBound, accuracy: 1e-9)

        for index in [0, original.size / 2, original.size - 1] {
            XCTAssertEqual(roundTrip.valueAtR(index), original.valueAtR(index), accuracy: 1e-9)
            XCTAssertEqual(roundTrip.valueAtG(index), original.valueAtG(index), accuracy: 1e-9)
            XCTAssertEqual(roundTrip.valueAtB(index), original.valueAtB(index), accuracy: 1e-9)
        }
    }

    func testReadAndWrite3DCube() throws {
        let cube = """
        LUT_3D_SIZE 2
        LUT_3D_INPUT_RANGE 0.0 1.0
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        1.0 1.0 0.0
        0.0 0.0 1.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        1.0 1.0 1.0
        """

        let result = try LUTCubeFormatter.read(string: cube)
        guard case let .lut3D(lut) = result else {
            XCTFail("Expected 3D LUT from inline cube string")
            return
        }

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.inputLowerBound, 0.0, accuracy: 1e-9)
        XCTAssertEqual(lut.inputUpperBound, 1.0, accuracy: 1e-9)
        XCTAssertEqual(lut.colorAt(r: 1, g: 0, b: 0), LUTColor.color(red: 1, green: 0, blue: 0))
        XCTAssertEqual(lut.colorAt(r: 0, g: 1, b: 1), LUTColor.color(red: 0, green: 1, blue: 1))

        let serialized = try LUTCubeFormatter.write(.lut3D(lut))
        XCTAssertTrue(serialized.contains("LUT_3D_SIZE 2"))

        let parsedAgain = try LUTCubeFormatter.read(string: serialized)
        guard case let .lut3D(roundTrip) = parsedAgain else {
            XCTFail("Expected 3D LUT after serializing and reading back")
            return
        }

        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    XCTAssertEqual(roundTrip.colorAt(r: r, g: g, b: b),
                                   lut.colorAt(r: r, g: g, b: b),
                                   "Mismatch at r: \(r) g: \(g) b: \(b)")
                }
            }
        }
    }
}
