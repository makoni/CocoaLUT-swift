import Foundation
import Testing
@testable import CocoaLUTSwift

enum FixtureLoader {
    static func payload(named resource: String,
                        extension fileExtension: String,
                        subdirectory: String,
                           file: StaticString = #fileID,
                        line: UInt = #line) throws -> LUTFormatterPayload {
        let url = try resourceURL(named: resource,
                                  extension: fileExtension,
                                  subdirectory: subdirectory,
                                  file: file,
                                  line: line)
        return try CocoaLUT.read(from: url)
    }

    static func resourceURL(named resource: String,
                            extension fileExtension: String,
                            subdirectory: String,
                                file: StaticString = #fileID,
                            line: UInt = #line) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: resource,
                               withExtension: fileExtension,
                               subdirectory: subdirectory),
            "Missing fixture \(resource).\(fileExtension) in \(subdirectory)",
            file: file,
            line: line
        )
    }
}

func XCTAssertIdentity(_ payload: LUTFormatterPayload,
                       tolerance: Double = 5e-4,
                       file: StaticString = #fileID,
                       line: UInt = #line) {
    switch payload {
    case .lut1D(let lut):
        assertIdentity(lut, tolerance: tolerance, file: file, line: line)
    case .lut3D(let lut):
        XCTAssertTrue(lut.equalsIdentity(tolerance: tolerance),
                      "Expected 3D LUT to equal identity",
                      file: file,
                      line: line)
    }
}

private func assertIdentity(_ lut: LUT1D,
                            tolerance: Double,
                            file: StaticString,
                            line: UInt) {
    guard lut.size > 1 else {
        XCTAssertEqual(lut.valueAtR(0), lut.inputLowerBound, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(lut.valueAtG(0), lut.inputLowerBound, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(lut.valueAtB(0), lut.inputLowerBound, accuracy: tolerance, file: file, line: line)
        return
    }

    for index in 0..<lut.size {
        let expected = LUTMath.remapNoError(Double(index),
                                            inputLow: 0,
                                            inputHigh: Double(lut.size - 1),
                                            outputLow: lut.inputLowerBound,
                                            outputHigh: lut.inputUpperBound)
        XCTAssertEqual(lut.valueAtR(index), expected, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(lut.valueAtG(index), expected, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(lut.valueAtB(index), expected, accuracy: tolerance, file: file, line: line)
    }
}
