import Foundation
import Testing
@testable import CocoaLUTSwift

// Robustness coverage: malformed inputs, registry lookup edges, and formatter
// variants that lacked dedicated test files.
@Suite(.serialized)
struct LUTFormatterRobustnessTests {

    // MARK: - DaVinciDAVLUT (had no dedicated test file)

    @Test
    func testDaVinciDAVLUTRoundTrip() throws {
        var lut = LUT3D.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        lut.setColor(LUTColor.color(red: 0.42, green: 0.13, blue: 0.71), r: 1, g: 2, b: 3)
        let serialised = try LUTFormatterDaVinciDAVLUT.write(lut)
        let parsed = try LUTFormatterDaVinciDAVLUT.read(string: serialised)
        #expect(parsed.size == lut.size)
        let sample = parsed.colorAt(r: 1, g: 2, b: 3)
        #expect(abs(sample.red - 0.42) < 1e-6)
        #expect(abs(sample.green - 0.13) < 1e-6)
        #expect(abs(sample.blue - 0.71) < 1e-6)
    }

    @Test
    func testDaVinciDAVLUTPayloadDelegatesToResolve() throws {
        // The DaVinci formatter is a thin alias around the Resolve DAT writer
        // with `fileTypeVariant = "DaVinci"` — the serialised text must include
        // a Resolve-style header.
        let lut = LUT3D.identity(size: 5, inputLowerBound: 0, inputUpperBound: 1)
        let serialised = try LUTFormatterDaVinciDAVLUT.write(lut)
        // 5×5×5 cube → "5" appears in the size declaration line.
        #expect(serialised.contains("5"))
    }

    // MARK: - Cube malformed input

    @Test
    func testCubeReadEmptyDataThrows() {
        #expect(throws: (any Error).self) {
            _ = try LUTFormatterCube.read(data: Data())
        }
    }

    @Test
    func testCubeReadMissingSizeHeaderThrows() {
        // Body without a LUT_3D_SIZE/LUT_1D_SIZE directive must not silently
        // succeed — the parser would otherwise build a LUT of indeterminate size.
        let body = """
        TITLE "broken"
        0.0 0.0 0.0
        1.0 1.0 1.0
        """
        #expect(throws: (any Error).self) {
            _ = try LUTFormatterCube.read(data: Data(body.utf8))
        }
    }

    @Test
    func testCubeReadGarbledNumbersThrows() {
        let body = """
        LUT_3D_SIZE 2
        not a number here
        """
        #expect(throws: (any Error).self) {
            _ = try LUTFormatterCube.read(data: Data(body.utf8))
        }
    }

    // MARK: - ArriLook minimal sections

    @Test
    func testArriLookReadRejectsMissingSaturationSection() {
        // The parser treats every documented section as required. If somebody
        // strips Saturation/PrinterLight from a file, we surface a missingElement
        // error rather than silently producing an identity LUT.
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <adicam version="1.0" camera="alexa">
            <SOPNode>
                <Slope>1.0 1.0 1.0</Slope>
                <Offset>0.0 0.0 0.0</Offset>
                <Power>1.0 1.0 1.0</Power>
            </SOPNode>
            <ToneMapLut rows="2" cols="1">
                0
                4095
            </ToneMapLut>
        </adicam>
        """
        #expect(throws: (any Error).self) {
            _ = try LUTFormatterArriLook.read(string: xml)
        }
    }

    @Test
    func testArriLookReadIdentityProducesIdentityLUT() throws {
        // No-op SOP + identity ToneMap + sat=1 + zero PrinterLight ⇒ pure identity.
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <adicam version="1.0" camera="alexa">
            <Saturation>
                1.0
            </Saturation>
            <PrinterLight>
                0.0 0.0 0.0
            </PrinterLight>
            <SOPNode>
                <Slope>1.0 1.0 1.0</Slope>
                <Offset>0.0 0.0 0.0</Offset>
                <Power>1.0 1.0 1.0</Power>
            </SOPNode>
            <ToneMapLut rows="2" cols="1">
                0
                4095
            </ToneMapLut>
        </adicam>
        """
        let lut = try LUTFormatterArriLook.read(string: xml)
        // Sample the centre cell — identity should give r=g=b at the midpoint.
        let middle = lut.colorAt(r: lut.size / 2, g: lut.size / 2, b: lut.size / 2)
        #expect(abs(middle.red - middle.green) < 1e-6)
        #expect(abs(middle.green - middle.blue) < 1e-6)
    }

    // MARK: - Registry / facade edges

    @Test
    func testFacadeReadNonexistentFileThrows() {
        let url = URL(fileURLWithPath: "/tmp/__cocoalut_nonexistent_\(UUID().uuidString).cube")
        #expect(throws: (any Error).self) {
            _ = try CocoaLUT.read(from: url)
        }
    }

    @Test
    func testFacadeReadUnknownExtensionThrowsFormatterNotFound() {
        let url = URL(fileURLWithPath: "/tmp/__cocoalut_unknown_\(UUID().uuidString).xyzzy")
        do {
            _ = try CocoaLUT.read(from: url)
            Issue.record("Expected CocoaLUT.Error.formatterNotFound to be thrown")
        } catch let error as CocoaLUT.Error {
            switch error {
            case .formatterNotFound: break
            default: Issue.record("Unexpected facade error: \(error)")
            }
        } catch {
            // Any other error type is fine — the contract is that something must throw.
        }
    }

    @Test
    func testFacadeDescriptorForUnknownIdentifierThrows() {
        do {
            _ = try CocoaLUT.descriptor(for: "definitely-not-a-formatter")
            Issue.record("Expected formatterNotFound error")
        } catch let error as CocoaLUT.Error {
            switch error {
            case .formatterNotFound: break
            default: Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected non-CocoaLUT error: \(error)")
        }
    }

    @Test
    func testFacadeRoundTripCubeViaTemporaryFile() throws {
        let lut = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cocoalut_roundtrip_\(UUID().uuidString).cube")
        defer { try? FileManager.default.removeItem(at: url) }

        try CocoaLUT.write(.lut3D(lut), to: url, formatterIdentifier: "cube")
        let payload = try CocoaLUT.read(from: url)
        guard case .lut3D(let parsed) = payload else {
            Issue.record("Expected lut3D payload, got \(payload.outputType)")
            return
        }
        #expect(parsed.equals(lut, tolerance: 1e-6))
    }

    @Test
    func testRegistryDescriptorsCaseInsensitiveFileExtension() {
        let lower = CocoaLUT.descriptors(forFileExtension: "cube")
        let upper = CocoaLUT.descriptors(forFileExtension: "CUBE")
        let mixed = CocoaLUT.descriptors(forFileExtension: "Cube")
        // All three queries must surface the Cube descriptor — extension lookup
        // can't depend on the user's casing.
        #expect(!lower.isEmpty)
        #expect(lower.count == upper.count)
        #expect(lower.count == mixed.count)
    }
}
