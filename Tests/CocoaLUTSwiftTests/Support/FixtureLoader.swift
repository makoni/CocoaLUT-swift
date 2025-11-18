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
        func missingFixtureComment() -> Comment {
            Comment("Missing fixture \(resource).\(fileExtension) in \(subdirectory)")
        }

        return try #require(
            Bundle.module.url(forResource: resource,
                              withExtension: fileExtension,
                              subdirectory: subdirectory),
            missingFixtureComment()
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
        #expect(
            lut.equalsIdentity(tolerance: tolerance),
            Comment("Expected 3D LUT to equal identity")
        )
    }
}

private func assertIdentity(_ lut: LUT1D,
                            tolerance: Double,
                            file: StaticString,
                            line: UInt) {
    guard lut.size > 1 else {
        assertApproximatelyEqual(lut.valueAtR(0), lut.inputLowerBound, tolerance: tolerance, channel: "R0")
        assertApproximatelyEqual(lut.valueAtG(0), lut.inputLowerBound, tolerance: tolerance, channel: "G0")
        assertApproximatelyEqual(lut.valueAtB(0), lut.inputLowerBound, tolerance: tolerance, channel: "B0")
        return
    }

    for index in 0..<lut.size {
        let expected = LUTMath.remapNoError(Double(index),
                                            inputLow: 0,
                                            inputHigh: Double(lut.size - 1),
                                            outputLow: lut.inputLowerBound,
                                            outputHigh: lut.inputUpperBound)
        assertApproximatelyEqual(lut.valueAtR(index), expected, tolerance: tolerance, channel: "R\(index)")
        assertApproximatelyEqual(lut.valueAtG(index), expected, tolerance: tolerance, channel: "G\(index)")
        assertApproximatelyEqual(lut.valueAtB(index), expected, tolerance: tolerance, channel: "B\(index)")
    }
}

private func assertApproximatelyEqual(_ actual: Double,
                                      _ expected: Double,
                                      tolerance: Double,
                                      channel: String) {
    #expect(
        abs(actual - expected) <= tolerance,
        Comment("\(channel) expected ≈ \(expected), got \(actual)")
    )
}
