import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTParserSampleTests {
    @MainActor
    @Test(arguments: ParserFixture.all)
    func testSampleLUTsProduceExpectedSizes(fixture: ParserFixture) throws {
        let payload = try FixtureLoader.payload(named: fixture.name,
                                                 extension: fixture.fileExtension,
                                                 subdirectory: fixture.subdirectory)
        guard case .lut3D(let lut) = payload else {
            Issue.record("Expected 3D LUT for \(fixture.testDescription)")
            return
        }
        #expect(lut.size == fixture.expectedSize)
    }
}

struct ParserFixture: CustomTestStringConvertible {
    let name: String
    let fileExtension: String
    let subdirectory: String
    let expectedSize: Int

    var testDescription: String { "\(name).\(fileExtension)" }

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
                      subdirectory: "TestLUTs/OpenColorIO/cube",
                      expectedSize: expectedSize)
    }

    private static func threeDL(_ name: String, expectedSize: Int) -> ParserFixture {
        ParserFixture(name: name,
                      fileExtension: "3dl",
                      subdirectory: "TestLUTs/OpenColorIO/3dl",
                      expectedSize: expectedSize)
    }
}
