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

    private func sampleILUTString() -> String {
        """
        0,0,0,0
        8192,4096,2048,0
        16383,16383,8192,0
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

    func testILUTDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterILUT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Blackmagic Design 1D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["ilut"])
        XCTAssertEqual(descriptor.output, .lut1D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

    let options = descriptor.defaultOptions?[LUTFormatterILUT.formatterIdentifier] as? [String: Any]
    XCTAssertEqual(options?["fileTypeVariant"] as? String, "ILUT")
    XCTAssertEqual(integer(from: options?["lutSize"]), 16384)
    }

    func testDescriptorsLookupByExtensionIncludesILUT() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "ILUT")
        XCTAssertEqual(descriptors.map { $0.id }, [LUTFormatterILUT.formatterIdentifier])
    }

    func testHaldDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterHaldCLUT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Hald CLUT")
        XCTAssertEqual(descriptor.fileExtensions, ["tiff", "tif"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterHaldCLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, ImageBasedFormatterVariant.tiff.rawValue)
        XCTAssertEqual(integer(from: options?["bitDepth"]), 16)
        XCTAssertEqual(integer(from: options?["lutSize"]), 36)
    }

    func testDescriptorsLookupByExtensionIncludesHald() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "TIFF")
        XCTAssertFalse(descriptors.isEmpty)
        let identifiers = Set(descriptors.map { $0.id })
        XCTAssertTrue(identifiers.contains(LUTFormatterHaldCLUT.formatterIdentifier))
    }

    func testUnwrappedDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterUnwrappedTexture.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Unwrapped Cube Image 3D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["png", "tiff", "tif"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterUnwrappedTexture.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: options?["bitDepth"]), 8)
        XCTAssertEqual(options?["fileTypeVariant"] as? String, ImageBasedFormatterVariant.tiff.rawValue)
    }

    func testDescriptorsLookupByExtensionIncludesUnwrapped() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "PNG")
        XCTAssertEqual(descriptors.map { $0.id }, [LUTFormatterUnwrappedTexture.formatterIdentifier])
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

    func testReadILUTByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.ilut")
        try sampleILUTString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterILUT.formatterIdentifier)
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from ILUT file")
            return
        }

        XCTAssertEqual(lut.size, 3)
        XCTAssertEqual(lut.valueAtR(1), 8192.0 / 16383.0, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterILUT.formatterIdentifier] as? [String: Any]
        XCTAssertNotNil(passthrough)
    }

    func testReadILUTFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.ilut")
        try sampleILUTString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from ILUT extension lookup")
            return
        }

        XCTAssertEqual(lut.size, 3)
        XCTAssertEqual(lut.valueAtB(2), 8192.0 / 16383.0, accuracy: 1e-9)
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

    func testWriteILUTRoundTrip() throws {
        let original = LUT1D.uniformCurve(size: 16, inputLowerBound: 0, inputUpperBound: 1)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.ilut")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut1D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterILUT.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterILUT.formatterIdentifier)
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from round-tripped ILUT file")
            return
        }

        XCTAssertEqual(lut.size, 16384)
        XCTAssertEqual(lut.valueAtR(0), 0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtR(lut.size - 1), 1, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterILUT.formatterIdentifier] as? [String: Any]
        XCTAssertNotNil(passthrough)
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

    func testReadHaldByIdentifier() throws {
        let lut = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)
        let image = try LUTFormatterHaldCLUT.image(from: lut, options: .init(bitDepth: 8))
        let data = try ImageBasedLUTUtilities.tiffData(from: image)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.tiff")
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterHaldCLUT.formatterIdentifier)
        guard case .lut3D(let decoded) = payload else {
            XCTFail("Expected LUT3D payload from Hald CLUT file")
            return
        }

        let quantizedTolerance = (1.0 / 255.0) + 1e-6
        XCTAssertTrue(decoded.equals(lut, tolerance: quantizedTolerance))
        let passthrough = decoded.passthroughFileOptions[LUTFormatterHaldCLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: passthrough?["bitDepth"]), 8)
        XCTAssertEqual(integer(from: passthrough?["lutSize"]), 9)
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

    func testReadUnwrappedTextureByIdentifier() throws {
        let size = 16
        let lut = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        let data = try LUTFormatterUnwrappedTexture.pngData(from: lut)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.png")
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterUnwrappedTexture.formatterIdentifier)
        guard case .lut3D(let decoded) = payload else {
            XCTFail("Expected LUT3D payload from unwrapped texture file")
            return
        }

        let quantizedTolerance = (1.0 / 255.0) + 1e-6
        XCTAssertTrue(decoded.equals(lut, tolerance: quantizedTolerance))

        let passthrough = decoded.passthroughFileOptions[LUTFormatterUnwrappedTexture.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: passthrough?["bitDepth"]), 8)
        XCTAssertEqual(integer(from: passthrough?["lutSize"]), size)
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, ImageBasedFormatterVariant.tiff.rawValue)
    }

    func testWriteUnwrappedTextureRoundTrip() throws {
        let original = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.png")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut3D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterUnwrappedTexture.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterUnwrappedTexture.formatterIdentifier)
        guard case .lut3D(let decoded) = payload else {
            XCTFail("Expected LUT3D payload from round-tripped unwrapped texture file")
            return
        }

        let quantizedTolerance = (1.0 / 255.0) + 1e-6
        XCTAssertTrue(decoded.equals(original, tolerance: quantizedTolerance))
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

    func testWriteHaldRoundTrip() throws {
        let original = LUT3D.identity(size: 9, inputLowerBound: 0, inputUpperBound: 1)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.tiff")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut3D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterHaldCLUT.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterHaldCLUT.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            XCTFail("Expected LUT3D payload from round-tripped Hald CLUT file")
            return
        }

        let quantizedTolerance = (1.0 / 255.0) + 1e-6
        XCTAssertTrue(lut.equals(original, tolerance: quantizedTolerance))
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
