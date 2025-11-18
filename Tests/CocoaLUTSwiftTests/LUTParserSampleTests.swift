import Testing
@testable import CocoaLUTSwift

@Suite
struct LUTParserSampleTests {
    @MainActor
    @Test
    func testSampleLUTsProduceExpectedSizes() throws {
        for fixture in ParserFixture.all {
            try XCTContext.runActivity(named: fixture.displayName) { _ in
                let payload = try FixtureLoader.payload(named: fixture.name,
                                                         extension: fixture.fileExtension,
                                                         subdirectory: fixture.subdirectory)
                guard case .lut3D(let lut) = payload else {
                    XCTFail("Expected 3D LUT for \(fixture.displayName)")
                    return
                }
                XCTAssertEqual(lut.size, fixture.expectedSize)
            }
        }
    }
}

private struct ParserFixture {
    let name: String
    let fileExtension: String
    let subdirectory: String
    let expectedSize: Int

    var displayName: String { "\(name).\(fileExtension)" }

    static let all: [ParserFixture] = [
        .cube("crosstalk", expectedSize: 17),
        .cube("halfred_iridas", expectedSize: 17),
        .cube("iridas", expectedSize: 2),
        .threeDL("crosstalk", expectedSize: 17),
        .threeDL("halfred_truelight", expectedSize: 17),
        .threeDL("halfred_truelight_log", expectedSize: 17)
    ]

    private static func cube(_ name: String, expectedSize: Int) -> ParserFixture {
        ParserFixture(name: name,
                      fileExtension: "cube",
                      subdirectory: "Test LUTs/OpenColorIO/cube",
                      expectedSize: expectedSize)
    }

    private static func threeDL(_ name: String, expectedSize: Int) -> ParserFixture {
        ParserFixture(name: name,
                      fileExtension: "3dl",
                      subdirectory: "Test LUTs/OpenColorIO/3dl",
                      expectedSize: expectedSize)
    }
}
