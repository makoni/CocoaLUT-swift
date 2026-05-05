import Foundation
import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTCubeFormatterTests {
    @Test
    func testReadLinearToBMDFilmCube() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "TestLinearToBMDFilm",
                withExtension: "cube",
                subdirectory: nil
            ),
            Comment("Missing TestLinearToBMDFilm.cube")
        )

        let result = try LUTCubeFormatter.read(url: url)
        guard case let .lut1D(lut) = result else {
            Issue.record(Comment("Expected to load a 1D LUT from cube file"))
            return
        }

        #expect(lut.size == 16)
        #expect(abs(lut.inputLowerBound - (-0.0071215555)) <= 1e-9)
        #expect(abs(lut.inputUpperBound - 5.7661304310) <= 1e-9)
        #expect(abs(lut.valueAtR(0) - 0.0) <= 1e-9)
        #expect(abs(lut.valueAtR(1) - 0.0070058769) <= 1e-9)

        let passthrough = lut.passthroughFileOptions[LUTCubeFormatter.formatterIdentifier] as? [String: String]
        #expect(passthrough?["fileTypeVariant"] == LUTCubeVariant.resolve.rawValue)
    }

    @Test
    func testRoundTripWriteRead1D() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "TestLinearToBMDFilm",
                withExtension: "cube",
                subdirectory: nil
            ),
            Comment("Missing TestLinearToBMDFilm.cube")
        )

        let originalResult = try LUTCubeFormatter.read(url: url)
        guard case let .lut1D(original) = originalResult else {
            Issue.record(Comment("Expected a 1D LUT"))
            return
        }

        let serialized = try LUTCubeFormatter.write(.lut1D(original))
        let roundTripResult = try LUTCubeFormatter.read(string: serialized)
        guard case let .lut1D(roundTrip) = roundTripResult else {
            Issue.record(Comment("Expected a 1D LUT from serialized data"))
            return
        }

        #expect(roundTrip.size == original.size)
        #expect(abs(roundTrip.inputLowerBound - original.inputLowerBound) <= 1e-9)
        #expect(abs(roundTrip.inputUpperBound - original.inputUpperBound) <= 1e-9)

        for index in [0, original.size / 2, original.size - 1] {
            #expect(abs(roundTrip.valueAtR(index) - original.valueAtR(index)) <= 1e-9)
            #expect(abs(roundTrip.valueAtG(index) - original.valueAtG(index)) <= 1e-9)
            #expect(abs(roundTrip.valueAtB(index) - original.valueAtB(index)) <= 1e-9)
        }
    }

    @Test
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
            Issue.record(Comment("Expected 3D LUT from inline cube string"))
            return
        }

        #expect(lut.size == 2)
        #expect(abs(lut.inputLowerBound - 0.0) <= 1e-9)
        #expect(abs(lut.inputUpperBound - 1.0) <= 1e-9)
        #expect(lut.colorAt(r: 1, g: 0, b: 0) == LUTColor.color(red: 1, green: 0, blue: 0))
        #expect(lut.colorAt(r: 0, g: 1, b: 1) == LUTColor.color(red: 0, green: 1, blue: 1))

        let serialized = try LUTCubeFormatter.write(.lut3D(lut))
        #expect(serialized.contains("LUT_3D_SIZE 2"))

        let parsedAgain = try LUTCubeFormatter.read(string: serialized)
        guard case let .lut3D(roundTrip) = parsedAgain else {
            Issue.record(Comment("Expected 3D LUT after serializing and reading back"))
            return
        }

        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    #expect(
                        roundTrip.colorAt(r: r, g: g, b: b) == lut.colorAt(r: r, g: g, b: b),
                        Comment("Mismatch at r: \(r) g: \(g) b: \(b)")
                    )
                }
            }
        }
    }
}
