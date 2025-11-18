import XCTest
@testable import CocoaLUTSwift

final class ObjCCompatibilityTests: XCTestCase {
    func testLUTDataRepresentationRoundTrip3D() throws {
        let identity = LUT.identity(size: 17,
                                    inputLowerBound: 0,
                                    inputUpperBound: 1)

        let data = try XCTUnwrap(identity.dataRepresentation, "Expected cube payload for identity LUT")
        let decoded = try XCTUnwrap(LUT(fromDataRepresentation: data))

        XCTAssertTrue(decoded.equals(identity, tolerance: 1e-9))
    }

    func testLUTDataRepresentationRoundTrip1D() throws {
        let curve = LUT1D.uniformCurve(size: 65,
                                       inputLowerBound: 0,
                                       inputUpperBound: 1)

        let cube = curve.toLUT3D(size: curve.size).asLUT()
        let data = try XCTUnwrap(cube.dataRepresentation, "Expected cube payload for converted 1D LUT")
        let decoded = try XCTUnwrap(LUT(fromDataRepresentation: data))

        let reconstructedCurve = LUT3D(lattice: decoded).toLUT1D()
        assertEqual(curve, reconstructedCurve, accuracy: 1e-9)
    }
}

private func assertEqual(_ lhs: LUT1D,
                         _ rhs: LUT1D,
                         accuracy: Double,
                         file: StaticString = #filePath,
                         line: UInt = #line) {
    XCTAssertEqual(lhs.size, rhs.size, file: file, line: line)
    XCTAssertEqual(lhs.inputLowerBound, rhs.inputLowerBound, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.inputUpperBound, rhs.inputUpperBound, accuracy: accuracy, file: file, line: line)

    for index in 0..<lhs.size {
        XCTAssertEqual(lhs.valueAtR(index), rhs.valueAtR(index), accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.valueAtG(index), rhs.valueAtG(index), accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.valueAtB(index), rhs.valueAtB(index), accuracy: accuracy, file: file, line: line)
    }
}
