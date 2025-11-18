import Foundation
import Testing
@testable import CocoaLUTSwift

@Suite
struct CocoaLUTFacadeTests {
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

    private func sampleOLUTString() -> String {
        """
        0,0,0,0,0,0
        2048,1024,0,2048,1024,0
        4095,4095,4095,4095,4095,4095
        """
    }

    private func sampleQuantelString() -> String {
        """
        max value 1023
        vertices 2
        blue is fastest changing
        red is slowest changing

        cube data
        R G B
        0 0 0
        0 0 1023
        0 1023 0
        0 1023 1023
        1023 0 0
        1023 0 1023
        1023 1023 0
        1023 1023 1023
        """
    }

    private func sampleResolveDATString() -> String {
        """
        # Resolve DAT sample
        3DLUTSIZE 2

        0.0 0.0 0.0
        0.0 0.0 1.0
        0.0 1.0 0.0
        0.0 1.0 1.0
        1.0 0.0 0.0
        1.0 0.2 0.8
        1.0 1.0 0.0
        1.0 1.0 1.0
        """
    }

    private func sampleMatchLightString() -> String {
        """
        lutSize = 3
        cubeSize = 2

        0 0 0
        1 1 1
        1 1 1
        # CUBE
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """
    }

    private func legacyKey(for canonicalID: String) -> String {
        "com.cocoalut.formatter.\(canonicalID.lowercased())"
    }

    private func assertDefaultOptionsIncludeLegacyAlias(_ descriptor: LUTFormatterDescriptor,
                                                        canonicalID: String,
                                                        file: StaticString = #fileID,
                                                        line: UInt = #line) {
        let legacyOptions = descriptor.defaultOptions?[legacyKey(for: canonicalID)] as? [String: Any]
        XCTAssertNotNil(legacyOptions, "Expected default options to include legacy alias for \(canonicalID)", file: file, line: line)
    }

    private func temporaryFileURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    @Test
    func testLegacyIdentifiersResolveRegisteredDescriptors() throws {
        let canonicalIdentifiers = [
            LUTCubeFormatter.formatterIdentifier,
            LUTFormatter3DL.formatterIdentifier,
            LUTFormatterHaldCLUT.formatterIdentifier,
            LUTFormatterILUT.formatterIdentifier,
            LUTFormatterOLUT.formatterIdentifier,
            LUTFormatterQuantel.formatterIdentifier,
            LUTFormatterFSIDAT.formatterIdentifier,
            LUTFormatterClipster.formatterIdentifier,
            LUTFormatterDiscreet1DLUT.formatterIdentifier,
            LUTFormatterCMSTestPattern.formatterIdentifier,
            LUTFormatterNucodaCMS.formatterIdentifier,
            LUTFormatterResolveDAT.formatterIdentifier,
            LUTFormatterDaVinciDAVLUT.formatterIdentifier,
            LUTFormatterMatchLight.formatterIdentifier,
            LUTFormatterArriLook.formatterIdentifier,
            LUTFormatterUnwrappedTexture.formatterIdentifier
        ]

        for identifier in canonicalIdentifiers {
            let descriptor = try CocoaLUT.descriptor(for: identifier)
            let legacyIdentifier = legacyKey(for: identifier)
            let legacyDescriptor = try CocoaLUT.descriptor(for: legacyIdentifier)
            XCTAssertEqual(legacyDescriptor.id, descriptor.id,
                           "Legacy identifier \(legacyIdentifier) should resolve to \(identifier)")
        }
    }

    @Test
    func testConstantsMirrorHelperValues() {
        XCTAssertEqual(CocoaLUT.suggestedMaxLUT1DSize, LUTConstants.suggestedMax1DSize)
        XCTAssertEqual(CocoaLUT.suggestedMaxLUT3DSize, LUTConstants.suggestedMax3DSize)
        XCTAssertEqual(CocoaLUT.maxCIColorCubeSize, LUTConstants.maxCIColorCubeSize)
        XCTAssertEqual(CocoaLUT.maxVVLUT1DFilterSize, LUTConstants.maxVVLUT1DFilterSize)
    }

    @Test
    func testDescriptorLookupThrowsForUnknownIdentifier() {
        XCTAssertThrowsError(try CocoaLUT.descriptor(for: "does-not-exist")) { error in
            guard case CocoaLUT.Error.formatterNotFound(let identifier) = error else {
                XCTFail("Expected formatterNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(identifier, "does-not-exist")
        }
    }

    @Test
    func testDescriptorsForUnknownExtensionAreEmpty() {
        XCTAssertTrue(CocoaLUT.descriptors(forFileExtension: "unknown").isEmpty)
    }

    @Test
    func testCubeDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: "cube")
        XCTAssertEqual(descriptor.name, "Cube LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["cube"])
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))
        XCTAssertEqual(descriptor.output, .either)
        XCTAssertEqual(descriptor.id, LUTCubeFormatter.formatterIdentifier)
        XCTAssertTrue(descriptor.alternateIdentifiers.contains(LUTCubeFormatter.legacyFormatterIdentifier))
        XCTAssertTrue(descriptor.alternateIdentifiers.contains("com.blackmagicdesign.cube"))

        let defaultOptions = descriptor.defaultOptions
        XCTAssertNotNil(defaultOptions?[LUTCubeFormatter.formatterIdentifier] as? [String: Any])
        XCTAssertNotNil(defaultOptions?[LUTCubeFormatter.legacyFormatterIdentifier] as? [String: Any])
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesCube() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "CUBE")
        XCTAssertEqual(descriptors.map { $0.id }, ["cube"])
    }

    @Test
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
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatter3DL.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludes3DL() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "3DL")
        XCTAssertEqual(descriptors.map { $0.id }, [LUTFormatter3DL.formatterIdentifier])
    }

    @Test
    func testILUTDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterILUT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Blackmagic Design 1D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["ilut"])
        XCTAssertEqual(descriptor.output, .lut1D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterILUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "ILUT")
        XCTAssertEqual(integer(from: options?["lutSize"]), 16384)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterILUT.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesILUT() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "ILUT")
        XCTAssertEqual(descriptors.map { $0.id }, [LUTFormatterILUT.formatterIdentifier])
    }

    @Test
    func testOLUTDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterOLUT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Blackmagic Design 1D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["olut"])
        XCTAssertEqual(descriptor.output, .lut1D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterOLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "OLUT")
        XCTAssertEqual(integer(from: options?["lutSize"]), 4096)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterOLUT.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesOLUT() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "OLUT")
        XCTAssertEqual(descriptors.map { $0.id }, [LUTFormatterOLUT.formatterIdentifier])
    }

    @Test
    func testQuantelDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterQuantel.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Quantel 3D LUT")
        XCTAssertEqual(Set(descriptor.fileExtensions), ["txt"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterQuantel.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "Quantel")
        XCTAssertEqual(integer(from: options?["lutSize"]), 33)
        XCTAssertEqual(integer(from: options?["integerMaxOutput"]), LUTMath.maxInteger(bitDepth: 16))
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterQuantel.formatterIdentifier)
    }

    @Test
    func testFSIDATDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterFSIDAT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "FSI DAT 3D LUT")
        XCTAssertEqual(Set(descriptor.fileExtensions.map { $0.lowercased() }), ["dat"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterFSIDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, LUTFormatterFSIDAT.Variant.v1.rawValue)
        XCTAssertEqual(integer(from: options?["lutSize"]), LUTFormatterFSIDAT.Variant.v1.lutSize)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterFSIDAT.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesDATVariants() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "DAT")
        let identifiers = Set(descriptors.map { $0.id })
        XCTAssertTrue(identifiers.contains(LUTFormatterFSIDAT.formatterIdentifier))
        XCTAssertTrue(identifiers.contains(LUTFormatterResolveDAT.formatterIdentifier))
    }

    @Test
    func testClipsterDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterClipster.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "DVS Clipster 3D LUT")
        XCTAssertEqual(Set(descriptor.fileExtensions.map { $0.lowercased() }), ["xml", "txt"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterClipster.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "Clipster")
        XCTAssertEqual(integer(from: options?["lutSize"]), 17)
        XCTAssertEqual(integer(from: options?["integerMaxOutput"]), LUTMath.maxInteger(bitDepth: 16))
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterClipster.formatterIdentifier)
    }

    @Test
    func testDiscreetDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterDiscreet1DLUT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Discreet 1D LUT")
        XCTAssertEqual(Set(descriptor.fileExtensions.map { $0.lowercased() }), ["lut"])
        XCTAssertEqual(descriptor.output, .lut1D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterDiscreet1DLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "Discreet")
        XCTAssertEqual(integer(from: options?["integerMaxOutput"]), LUTMath.maxInteger(bitDepth: 12))
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterDiscreet1DLUT.formatterIdentifier)
    }

    @Test
    func testCMSDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterCMSTestPattern.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "CMS Test Pattern Image 3D LUT")
        XCTAssertEqual(Set(descriptor.fileExtensions.map { $0.lowercased() }), ["tiff", "tif", "png"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterCMSTestPattern.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, ImageBasedFormatterVariant.tiff.rawValue)
        XCTAssertEqual(integer(from: options?["bitDepth"]), 8)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterCMSTestPattern.formatterIdentifier)
    }

    @Test
    func testNucodaDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterNucodaCMS.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Nucoda CMS LUT")
        XCTAssertEqual(Set(descriptor.fileExtensions.map { $0.lowercased() }), ["cms"])
        XCTAssertEqual(descriptor.output, .either)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterNucodaCMS.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, LUTFormatterNucodaCMS.Variant.v3.rawValue)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterNucodaCMS.formatterIdentifier)
    }

    @Test
    func testArriLookDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterArriLook.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Arri Look")
        XCTAssertEqual(Set(descriptor.fileExtensions.map { $0.lowercased() }), ["xml"])
        XCTAssertEqual(descriptor.output, .either)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterArriLook.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "Arri")
        XCTAssertEqual(integer(from: options?["lutSize"]), 4096)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterArriLook.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesXMLFormatters() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "xml")
        let identifiers = Set(descriptors.map { $0.id })
        XCTAssertTrue(identifiers.contains(LUTFormatterClipster.formatterIdentifier))
        XCTAssertTrue(identifiers.contains(LUTFormatterArriLook.formatterIdentifier))
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesQuantel() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "TXT")
        XCTAssertTrue(descriptors.contains { $0.id == LUTFormatterQuantel.formatterIdentifier })
    }

    @Test
    func testResolveDATDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterResolveDAT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Resolve DAT 3D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["dat"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "Resolve")
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterResolveDAT.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesResolveDAT() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "DAT")
        XCTAssertTrue(descriptors.contains { $0.id == LUTFormatterResolveDAT.formatterIdentifier })
    }

    @Test
    func testDaVinciDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterDaVinciDAVLUT.formatterIdentifier)
        XCTAssertEqual(descriptor.name, LUTFormatterDaVinciDAVLUT.formatterName())
        XCTAssertEqual(descriptor.fileExtensions, LUTFormatterDaVinciDAVLUT.fileExtensions())
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let resolveOptions = descriptor.defaultOptions?[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(resolveOptions?["fileTypeVariant"] as? String, "DaVinci")
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterDaVinciDAVLUT.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesDaVinci() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "DAVLUT")
        XCTAssertTrue(descriptors.contains { $0.id == LUTFormatterDaVinciDAVLUT.formatterIdentifier })
    }

    @Test
    func testMatchLightDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterMatchLight.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "LightIllusion MatchLight 3D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["mlc"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains(.read))
        XCTAssertFalse(descriptor.roles.contains(.write))

        let options = descriptor.defaultOptions?[LUTFormatterMatchLight.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(options?["fileTypeVariant"] as? String, "MatchLight")
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterMatchLight.formatterIdentifier)
    }
    
    @Test
    
    func testMatchLightAliasLookupResolvesDescriptor() throws {
        let camelCase = try CocoaLUT.descriptor(for: "MatchLight")
        XCTAssertEqual(camelCase.id, LUTFormatterMatchLight.formatterIdentifier)

        let lowercase = try CocoaLUT.descriptor(for: "matchlight")
        XCTAssertEqual(lowercase.id, LUTFormatterMatchLight.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesMatchLight() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "MLC")
        XCTAssertTrue(descriptors.contains { $0.id == LUTFormatterMatchLight.formatterIdentifier })
    }

    @Test
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
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterHaldCLUT.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesHald() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "TIFF")
        XCTAssertFalse(descriptors.isEmpty)
        let identifiers = Set(descriptors.map { $0.id })
        XCTAssertTrue(identifiers.contains(LUTFormatterHaldCLUT.formatterIdentifier))
    }

    @Test
    func testUnwrappedDescriptorIsRegistered() throws {
        let descriptor = try CocoaLUT.descriptor(for: LUTFormatterUnwrappedTexture.formatterIdentifier)
        XCTAssertEqual(descriptor.name, "Unwrapped Cube Image 3D LUT")
        XCTAssertEqual(descriptor.fileExtensions, ["png", "tiff", "tif"])
        XCTAssertEqual(descriptor.output, .lut3D)
        XCTAssertTrue(descriptor.roles.contains([.read, .write]))

        let options = descriptor.defaultOptions?[LUTFormatterUnwrappedTexture.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: options?["bitDepth"]), 8)
        XCTAssertEqual(options?["fileTypeVariant"] as? String, ImageBasedFormatterVariant.tiff.rawValue)
        assertDefaultOptionsIncludeLegacyAlias(descriptor, canonicalID: LUTFormatterUnwrappedTexture.formatterIdentifier)
    }

    @Test
    func testDescriptorsLookupByExtensionIncludesUnwrapped() {
        let descriptors = CocoaLUT.descriptors(forFileExtension: "PNG")
        XCTAssertFalse(descriptors.isEmpty)
        let identifiers = Set(descriptors.map { $0.id })
        XCTAssertTrue(identifiers.contains(LUTFormatterUnwrappedTexture.formatterIdentifier))
    }

    @Test
    func testReadCubeByIdentifier() throws {
        let payload = try CocoaLUT.read(from: cubeURL(), formatterIdentifier: "cube")
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from cube file")
            return
        }

        let canonicalKey = LUTCubeFormatter.formatterIdentifier
        let formatterOptions = lut.passthroughFileOptions[canonicalKey] as? [String: Any]
        let legacyOptions = lut.passthroughFileOptions[legacyKey(for: canonicalKey)] as? [String: Any]
        let blackmagicOptions = lut.passthroughFileOptions["com.blackmagicdesign.cube"] as? [String: Any]

        XCTAssertNotNil(formatterOptions)
        XCTAssertNotNil(legacyOptions)
        XCTAssertNotNil(blackmagicOptions)
        XCTAssertEqual(formatterOptions?["fileTypeVariant"] as? String, legacyOptions?["fileTypeVariant"] as? String)
        XCTAssertEqual(formatterOptions?["fileTypeVariant"] as? String, blackmagicOptions?["fileTypeVariant"] as? String)
    }

    @Test
    func testReadCubeFallsBackToExtensionMatching() throws {
        let payload = try CocoaLUT.read(from: cubeURL())
        guard case .lut1D = payload else {
            XCTFail("Expected LUT1D payload from cube file")
            return
        }
    }

    @Test
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
    let legacyOptions = lut.passthroughFileOptions[legacyKey(for: LUTFormatterILUT.formatterIdentifier)] as? [String: Any]
    XCTAssertNotNil(legacyOptions)
    }

    @Test
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

    @Test
    func testReadOLUTByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.olut")
        try sampleOLUTString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterOLUT.formatterIdentifier)
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from OLUT file")
            return
        }

        XCTAssertEqual(lut.size, 3)
        XCTAssertEqual(lut.valueAtR(1), 2048.0 / 4095.0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtG(1), 1024.0 / 4095.0, accuracy: 1e-9)
        XCTAssertEqual(lut.valueAtB(0), 0, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterOLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: passthrough?["lutSize"]), 3)
    let legacyOptions = lut.passthroughFileOptions[legacyKey(for: LUTFormatterOLUT.formatterIdentifier)] as? [String: Any]
    XCTAssertNotNil(legacyOptions)
    }

    @Test
    func testReadOLUTFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.olut")
        try sampleOLUTString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from OLUT extension lookup")
            return
        }

        XCTAssertEqual(lut.size, 3)
        XCTAssertEqual(lut.valueAtB(2), 1, accuracy: 1e-9)
    }

    @Test
    func testReadQuantelByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.txt")
        try sampleQuantelString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterQuantel.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            XCTFail("Expected LUT3D payload from Quantel file")
            return
        }

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).red, 1, accuracy: 1e-6)
        let passthrough = lut.passthroughFileOptions[LUTFormatterQuantel.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: passthrough?["lutSize"]), 2)
        XCTAssertEqual(integer(from: passthrough?["integerMaxOutput"]), 1023)
    let legacyOptions = lut.passthroughFileOptions[legacyKey(for: LUTFormatterQuantel.formatterIdentifier)] as? [String: Any]
    XCTAssertNotNil(legacyOptions)
    }

    @Test
    func testReadQuantelFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.txt")
        try sampleQuantelString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut3D(let lut) = payload else {
            XCTFail("Expected LUT3D payload from Quantel extension lookup")
            return
        }

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 0, g: 0, b: 1).blue, 1023.0 / 1023.0, accuracy: 1e-9)
    }

    @Test
    func testReadResolveDATByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.dat")
        try sampleResolveDATString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterResolveDAT.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from Resolve DAT file")
        }

        XCTAssertEqual(lut.size, 2)
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Resolve")
        let legacyOptions = lut.passthroughFileOptions[legacyKey(for: LUTFormatterResolveDAT.formatterIdentifier)] as? [String: Any]
        XCTAssertNotNil(legacyOptions)
    }

    @Test
    func testReadResolveDATFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.dat")
        try sampleResolveDATString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from Resolve DAT extension lookup")
        }

        XCTAssertEqual(lut.size, 2)
    }

    @Test
    func testReadDaVinciByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.davlut")
        try sampleResolveDATString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterDaVinciDAVLUT.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from DaVinci DAVLUT file")
        }

        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "DaVinci")
        let canonicalKey = LUTFormatterDaVinciDAVLUT.formatterIdentifier
        let canonicalOptions = lut.passthroughFileOptions[canonicalKey] as? [String: Any]
        XCTAssertNotNil(canonicalOptions)
        let legacyOptions = lut.passthroughFileOptions[legacyKey(for: canonicalKey)] as? [String: Any]
        XCTAssertNotNil(legacyOptions)
    }

    @Test
    func testReadDaVinciFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.davlut")
        try sampleResolveDATString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from DaVinci extension lookup")
        }

        XCTAssertEqual(lut.size, 2)
    }

    @Test
    func testReadMatchLightByIdentifier() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.mlc")
        try sampleMatchLightString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterMatchLight.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from MatchLight file")
        }

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 1, g: 1, b: 1).red, 1, accuracy: 1e-9)
        let passthrough = lut.passthroughFileOptions[LUTFormatterMatchLight.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "MatchLight")
        XCTAssertEqual(integer(from: passthrough?["lut1DSize"]), 3)
        XCTAssertEqual(integer(from: passthrough?["lut3DSize"]), 2)
        let legacyOptions = lut.passthroughFileOptions[legacyKey(for: LUTFormatterMatchLight.formatterIdentifier)] as? [String: Any]
        XCTAssertNotNil(legacyOptions)
    }

    @Test
    func testReadMatchLightFallsBackToExtensionMatching() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("fallback.mlc")
        try sampleMatchLightString().write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try CocoaLUT.read(from: fileURL)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from MatchLight extension lookup")
        }

        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.colorAt(r: 0, g: 0, b: 1).blue, 1, accuracy: 1e-9)
    }

    @Test
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

    @Test
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

    @Test
    func testWriteOLUTRoundTrip() throws {
        var original = LUT1D(redCurve: [0, 0.25, 0.5, 0.75],
                              greenCurve: [0, 0.5, 0.25, 1],
                              blueCurve: [1, 0.5, 0.25, 0],
                              inputLowerBound: 0,
                              inputUpperBound: 1)
        original.passthroughFileOptions = [
            LUTFormatterOLUT.formatterIdentifier: ["lutSize": original.size]
        ]

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.olut")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut1D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterOLUT.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterOLUT.formatterIdentifier)
        guard case .lut1D(let lut) = payload else {
            XCTFail("Expected LUT1D payload from round-tripped OLUT file")
            return
        }

        XCTAssertEqual(lut.size, original.size)
        XCTAssertEqual(lut.valueAtR(0), original.valueAtR(0), accuracy: 1e-9)
        let quantizedTolerance = (1.0 / 4095.0) + 1e-6
        XCTAssertEqual(lut.valueAtG(1), original.valueAtG(1), accuracy: quantizedTolerance)
        XCTAssertEqual(lut.valueAtB(lut.size - 1), original.valueAtB(original.size - 1), accuracy: quantizedTolerance)
        let passthrough = lut.passthroughFileOptions[LUTFormatterOLUT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: passthrough?["lutSize"]), original.size)
    }

    @Test
    func testWriteQuantelRoundTrip() throws {
        var original = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        original.passthroughFileOptions = [
            LUTFormatterQuantel.formatterIdentifier: [
                "fileTypeVariant": "Quantel",
                "integerMaxOutput": LUTMath.maxInteger(bitDepth: 10),
                "lutSize": original.size
            ]
        ]

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.txt")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut3D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterQuantel.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterQuantel.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            XCTFail("Expected LUT3D payload from round-tripped Quantel file")
            return
        }

        XCTAssertEqual(lut.size, original.size)
        XCTAssertTrue(lut.equals(original, tolerance: 1e-6))
        let passthrough = lut.passthroughFileOptions[LUTFormatterQuantel.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(integer(from: passthrough?["lutSize"]), original.size)
        XCTAssertEqual(integer(from: passthrough?["integerMaxOutput"]), LUTMath.maxInteger(bitDepth: 10))
    }

    @Test
    func testWriteQuantelWithLegacyOptions() throws {
        let lut = LUT3D.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let payload = LUTFormatterPayload.lut3D(lut)
        let fileURL = temporaryFileURL(ext: "txt")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let legacy = legacyKey(for: LUTFormatterQuantel.formatterIdentifier)
        let options: [String: Any] = [legacy: [
            "integerMaxOutput": LUTMath.maxInteger(bitDepth: 16),
            "lutSize": lut.size
        ]]

        try CocoaLUT.write(payload,
                           to: fileURL,
                           formatterIdentifier: LUTFormatterQuantel.formatterIdentifier,
                           options: options)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let readPayload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterQuantel.formatterIdentifier)
        guard case .lut3D(let readLUT) = readPayload else {
            return XCTFail("Expected LUT3D payload from Quantel file written with legacy options")
        }

        let canonicalOptions = readLUT.passthroughFileOptions[LUTFormatterQuantel.formatterIdentifier] as? [String: Any]
        let legacyOptions = readLUT.passthroughFileOptions[legacy] as? [String: Any]
        XCTAssertNotNil(canonicalOptions)
        XCTAssertNotNil(legacyOptions)
    }

    @Test
    func testWriteResolveDATRoundTrip() throws {
        var original = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        original.passthroughFileOptions = [
            LUTFormatterResolveDAT.formatterIdentifier: [
                "fileTypeVariant": "Resolve"
            ]
        ]

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.dat")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut3D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterResolveDAT.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterResolveDAT.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from round-tripped Resolve DAT file")
        }

    XCTAssertTrue(lut.equals(original, tolerance: 1e-6))
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "Resolve")
    }

    @Test
    func testWriteDaVinciRoundTrip() throws {
        var original = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        original.passthroughFileOptions = [
            LUTFormatterResolveDAT.formatterIdentifier: [
                "fileTypeVariant": "DaVinci"
            ]
        ]

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("roundtrip.davlut")
        defer { try? FileManager.default.removeItem(at: directory) }

        try CocoaLUT.write(.lut3D(original),
                           to: fileURL,
                           formatterIdentifier: LUTFormatterDaVinciDAVLUT.formatterIdentifier)

        let payload = try CocoaLUT.read(from: fileURL, formatterIdentifier: LUTFormatterDaVinciDAVLUT.formatterIdentifier)
        guard case .lut3D(let lut) = payload else {
            return XCTFail("Expected LUT3D payload from round-tripped DaVinci file")
        }

    XCTAssertTrue(lut.equals(original, tolerance: 1e-6))
        let passthrough = lut.passthroughFileOptions[LUTFormatterResolveDAT.formatterIdentifier] as? [String: Any]
        XCTAssertEqual(passthrough?["fileTypeVariant"] as? String, "DaVinci")
    }

    @Test
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

    @Test
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

    @Test
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

    @Test
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

    @Test
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

    @Test
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

    @Test
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
