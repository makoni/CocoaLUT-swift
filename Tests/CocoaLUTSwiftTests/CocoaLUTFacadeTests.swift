import Foundation
import XCTest
@testable import CocoaLUT_swift

final class CocoaLUTFacadeTests: XCTestCase {
    private func cubeURL() throws -> URL {
        try XCTUnwrap(Bundle.module.url(
            forResource: "TestLinearToBMDFilm",
            withExtension: "cube",
            subdirectory: nil
        ))
    }

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

    func testCubeDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: "cube")
        XCTAssertEqual(descriptor.name, "Cube LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["cube"])
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))
        XCTAssertEqual(descriptor.output, .either)
        XCTAssertTrue(descriptor.alternateIdentifiers.contains(LUTCubeFormatter.formatterIdentifier))
    }

    func testDescriptorsLookupByExtensionIncludesCube() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "CUBE")
        XCTAssertEqual(descriptors.map { $0.id }, ["cube"])
    }

    func testReadCubeByIdentifier() throws {
        let payload = try CocoaLUT.read(from: cubeURL(), formatterIdentifier: "cube")
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from cube file")
            return
        }

        let formatterOptions = lut.passthroughFileOptions[LUTCubeFormatter.formatterIdentifier] as? [String: Any]
        let legacyOptions = lut.passthroughFileOptions["cube"] as? [String: Any]

        XCTAssertEqual(formatterOptions?["fileTypeVariant"] as? String, legacyOptions?["fileTypeVariant"] as? String)
        XCTAssertNotNil(formatterOptions)
        XCTAssertNotNil(legacyOptions)
    }

    func testReadCubeFallsBackToExtensionMatching() throws {
        let payload = try CocoaLUT.read(from: cubeURL())
        guard case .lut1D = payload else {
            XCTFail("Expected LUT1D payload from cube file")
            return
        }
    }

    func testWriteCubeRoundTrip() throws {
        let originalPayload = try CocoaLUT.read(from: cubeURL())
        guard case .lut1D(let lut) = originalPayload else {
            XCTFail("Expected LUT1D payload from cube file")
            return
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tempURL = directory.appendingPathComponent("roundtrip.cube")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut1D(lut), to: tempURL, formatterIdentifier: "cube")

        let roundTripped = try CocoaLUT.read(from: tempURL, formatterIdentifier: "cube")
        guard case .lut1D(let roundTripLUT) = roundTripped else {
            XCTFail("Expected LUT1D payload from round-tripped file")
            return
        }

        XCTAssertEqual(roundTripLUT.size, lut.size)
        XCTAssertEqual(roundTripLUT.inputLowerBound, lut.inputLowerBound, accuracy: 1e-9)
        XCTAssertEqual(roundTripLUT.inputUpperBound, lut.inputUpperBound, accuracy: 1e-9)
        XCTAssertEqual(roundTripLUT.valueAtR(0), lut.valueAtR(0), accuracy: 1e-9)
        XCTAssertEqual(roundTripLUT.valueAtR(lut.size - 1), lut.valueAtR(lut.size - 1), accuracy: 1e-9)
    }
}
