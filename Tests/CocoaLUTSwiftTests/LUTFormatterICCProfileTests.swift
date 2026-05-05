#if canImport(AppKit)
import AppKit
import Testing
@testable import CocoaLUTSwift

@MainActor

@Suite(.serialized)
struct LUTFormatterICCProfileTests {
    @Test
    func testReadGenericRGBProfileProducesIdentityTransform() throws {
        let colorSpace = NSColorSpace.genericRGB
        let data = try #require(colorSpace.iccProfileData)
        let lut = try LUTFormatterICCProfile.read(data: data, size: 17)

        #expect(lut.size == 17)
        let reference = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let sampleIndices = [0, 8, 16]
        for r in sampleIndices {
            for g in sampleIndices {
                for b in sampleIndices {
                    let transformed = lut.colorAt(r: r, g: g, b: b)
                    let expected = reference.colorAt(r: r, g: g, b: b)
                    #expect(abs(transformed.red - expected.red) < 1e-6, "Red mismatch at (\(r),\(g),\(b))")
                    #expect(abs(transformed.green - expected.green) < 1e-6, "Green mismatch at (\(r),\(g),\(b))")
                    #expect(abs(transformed.blue - expected.blue) < 1e-6, "Blue mismatch at (\(r),\(g),\(b))")
                }
            }
        }

        let passthrough = lut.passthroughFileOptions[LUTFormatterICCProfile.formatterIdentifier] as? [String: Any]
        #expect(passthrough != nil)
        #expect(passthrough?.isEmpty ?? false)
    }

    @Test
    func testReadFromURLMatchesDataPath() throws {
        let colorSpace = NSColorSpace.genericRGB
        let data = try #require(colorSpace.iccProfileData)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("icc")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let lut = try LUTFormatterICCProfile.read(url: tempURL, size: 9)
        #expect(lut.size == 9)
    }

    @Test
    func testUnsupportedComponentCountThrows() throws {
        let colorSpace = NSColorSpace.genericCMYK
        let data = try #require(colorSpace.iccProfileData)

        #expect {
            try LUTFormatterICCProfile.read(data: data)
        } throws: { error in
            error as? LUTFormatterICCProfileError == .unsupportedComponentCount(4)
        }
    }

    @Test
    func testInvalidDataThrows() {
        let data = Data(repeating: 0xAA, count: 32)
        #expect {
            try LUTFormatterICCProfile.read(data: data)
        } throws: { error in
            error as? LUTFormatterICCProfileError == .invalidProfile
        }
    }
}
#endif
