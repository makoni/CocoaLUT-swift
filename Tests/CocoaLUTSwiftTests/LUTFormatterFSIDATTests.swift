import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTFormatterFSIDATTests {
    @Test
    func testVariantV2RoundTripPreservesMetadata() throws {
        var lut = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        lut.title = "Sample"
        lut.descriptionText = "Identity LUT"
        lut.metadata = ["version": "1.0", "model": "XM55"]

        let data = try LUTFormatterFSIDAT.write(lut, options: .init(variant: .v2))
        let decoded = try LUTFormatterFSIDAT.read(data: data)

        #expect(decoded.equals(lut, tolerance: Self.quantizationTolerance(for: .v2)))
        #expect(decoded.title == "Sample")
        #expect(decoded.descriptionText == "Identity LUT")
        #expect(decoded.metadata["version"] as? String == "1.0")
        #expect(decoded.metadata["model"] as? String == "XM55")
        let passthrough = decoded.passthroughFileOptions["fsiDAT"] as? [String: Any]
        #expect(passthrough?["fileTypeVariant"] as? String == "v2")
        #expect(passthrough?["lutSize"] as? Int == 17)
    }

    @Test
    func testVariantV1RoundTrip() throws {
        let lut = LUT3D.identity(size: 64, inputLowerBound: 0, inputUpperBound: 1)
        let data = try LUTFormatterFSIDAT.write(lut, options: .init(variant: .v1))
        let decoded = try LUTFormatterFSIDAT.read(data: data)
        #expect(decoded.equals(lut, tolerance: Self.quantizationTolerance(for: .v1)))
    }

    @Test
    func testWriteThrowsForMismatchedSize() throws {
        let lut = LUT3D.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        #expect {
            try LUTFormatterFSIDAT.write(lut, options: .init(variant: .v1))
        } throws: { error in
            guard case let LUTFormatterFSIDATError.invalidLUTSize(expected, actual) = error else {
                return false
            }
            return expected == 64 && actual == 17
        }
    }

    @Test
    func testReadRejectsInvalidFile() {
        let data = Data(count: 64)
        #expect(throws: Error.self) {
            try LUTFormatterFSIDAT.read(data: data)
        }
    }
}

private extension LUTFormatterFSIDATTests {
    static func quantizationTolerance(for variant: LUTFormatterFSIDAT.Variant) -> Double {
        // Use half a quantization step per channel and convert to Euclidean space.
        let scale = variant.dataScale
        return sqrt(3.0) * 0.5 / scale
    }
}
