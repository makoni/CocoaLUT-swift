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

    private func sample3DLString() -> String {
        """
        # Sample 3DL
        0 4095

        0 0 0
        0 0 4095
        0 4095 0
        0 4095 4095
        4095 0 0
        4095 0 4095
        4095 4095 0
        4095 4095 4095
        """
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

    func testThreeDLDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatter3DL.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Autodesk 3D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["3dl"])
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))
        XCTAssertEqual(descriptor.output, .lut3D)

        let defaultOptions = descriptor.defaultOptions?[LUTFormatter3DL.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(defaultOptions?["fileTypeVariant"] as? String, LUTFormatter3DL.Variant.nuke.rawValue)
        XCTAssertEqual(integer(from: defaultOptions?["integerMaxOutput"]), LUTMath.maxInteger(bitDepth: 16))
        XCTAssertEqual(integer(from: defaultOptions?["lutSize"]), 32)
    }

    func testDescriptorsLookupByExtensionIncludes3DL() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "3DL")
        XCTAssertEqual(descriptors.map { $0.id }, [LUTFormatter3DL.formatterIdentifier])
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

    func testRead3DLByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.3dl")
        try sample3DLString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatter3DL.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            XCTFail("Expected LUT3D payload from 3DL file")
            return
        }

        XCTAssertEqual(lut.size, 2)
        let passthrough = lut.passthroughFileOptions[LUTFormatter3DL.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, LUTFormatter3DL.Variant.nuke.rawValue)
    }

    func testRead3DLFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.3dl")
        try sample3DLString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut3D(let lut) = payload else {
            XCTFail("Expected LUT3D payload from extension-based read")
            return
        }

        XCTAssertEqual(lut.size, 2)
    }

    func testWrite3DLRoundTrip() throws {
        let original = try LUTFormatter3DL.read(string: sample3DLString())

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.3dl")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut3D(original), to: fileURL, formatterIdentifier: LUTFormatter3DL.formatterIdentifier)

        let roundTripped = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatter3DL.formatterIdentifier)
        guard case .lut3D(let lut) = roundTripped else {
            XCTFail("Expected LUT3D payload from round-tripped 3DL file")
            return
        }

        XCTAssertEqual(lut.size, original.size)
        XCTAssertEqual(lut.colorAt(r: 1, g: 0, b: 1).red, original.colorAt(r: 1, g: 0, b: 1).red, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatter3DL.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, LUTFormatter3DL.Variant.nuke.rawValue)
    }

    private func integer(from value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }
}
