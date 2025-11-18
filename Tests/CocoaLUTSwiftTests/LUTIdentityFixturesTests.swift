import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTIdentityFixturesTests {
    @MainActor
    @Test(arguments: IdentityFixture.all)
    func testLegacyIdentityFixturesDecodeToIdentity(fixture: IdentityFixture) throws {
        let payload = try FixtureLoader.payload(named: fixture.name,
                                                 extension: fixture.fileExtension,
                                                 subdirectory: IdentityFixture.subdirectory)
        expectIdentity(payload, tolerance: fixture.tolerance)
    }
}

struct IdentityFixture: CustomTestStringConvertible {
    static let subdirectory = "Test LUTs/identity"

    let name: String
    let fileExtension: String
    let tolerance: Double

    var testDescription: String { "\(name).\(fileExtension)" }

    init(_ name: String, _ fileExtension: String, tolerance: Double = 5e-4) {
        self.name = name
        self.fileExtension = fileExtension
        self.tolerance = tolerance
    }

    static let all: [IdentityFixture] = [
        .init("identity_DaVinciResolve33_3D", "cube"),
        .init("identity_DaVinciResolve1024_1D", "cube"),
        .init("identity_Lustre17", "3dl"),
        .init("identity_Lustre17_12bits", "3dl"),
        .init("identity_Nuke32_12bits", "3dl"),
        .init("identity_Nuke32_16bits", "3dl"),
        .init("identity_Smoke17_12bits", "3dl"),
        .init("identity_DaVinci33", "dat"),
        .init("identity_FSI64", "dat"),
        .init("identity_DaVinci17", "davlut"),
        .init("identity_DaVinci33", "davlut"),
        .init("identity_Discreet1D", "lut"),
        .init("identity_Nuke32_16bits", "lut"),
        .init("identity_resolve_olut_12x6", "olut"),
        .init("identity_Nuke32_16bits", "ilut"),
        .init("identity_resolve_ilut_14x4", "ilut"),
        .init("identity_NucodaCMS33", "cms"),
        .init("identity_Quantel33", "txt"),
        .init("identity_DVSClipster17", "xml"),
        .init("identity_CMSTestPattern33", "tiff"),
        .init("identity_UnwrappedCube33", "tiff"),
        .init("identity_HaldCLUT36", "tiff")
    ]
}
