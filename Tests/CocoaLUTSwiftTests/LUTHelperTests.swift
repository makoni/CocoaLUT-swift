import CoreGraphics
import Foundation
import XCTest
@testable import CocoaLUT_swift

final class LUTHelperTests: XCTestCase {
    func testClampVariants() {
        XCTAssertEqual(LUTMath.clamp(1.5, lower: 0, upper: 1), 1)
        XCTAssertEqual(LUTMath.clamp01(-0.5), 0)
        XCTAssertEqual(LUTMath.clampLowerBound(-1, lowerBound: 0), 0)
        XCTAssertEqual(LUTMath.clampUpperBound(5, upperBound: 1), 1)
        XCTAssertTrue(LUTMath.outOfBounds(5, lowerBound: 0, upperBound: 1, inclusive: true))
        XCTAssertFalse(LUTMath.outOfBounds(1, lowerBound: 0, upperBound: 1, inclusive: true))
    }

    func testRemapVariants() {
        XCTAssertEqual(LUTMath.remapNoError(0.5, inputLow: 0, inputHigh: 1, outputLow: 0, outputHigh: 10), 5)
        XCTAssertEqual(LUTMath.remapInt01(128, maxValue: 255), 0.5019607843137255, accuracy: 1e-6)
        XCTAssertEqual(LUTMath.remapInt01(8, bitDepthMax: 15), 8.0 / 15.0)
        XCTAssertEqual(LUTMath.lerp(0, 10, t: 0.5), 5)
        XCTAssertEqual(LUTMath.smoothstep(0, 1, percentage: 0.5), 0.5, accuracy: 1e-6)
        XCTAssertEqual(LUTMath.smootherstep(0, 1, percentage: 0.5), 0.5, accuracy: 1e-6)
    }

    func testIndicesGeneration() {
        XCTAssertEqual(LUTMath.indicesIntegerArray(start: 0, end: 4, count: 5), [0, 1, 2, 3, 4])
        XCTAssertEqual(LUTMath.indicesIntegerArrayLegacy(start: 0, end: 4, count: 5), [0, 1, 3, 4, 4])
        let doubles = LUTMath.indicesDoubleArray(start: 0, end: 1, count: 3)
        XCTAssertEqual(doubles.count, 3)
        zip(doubles, [0.0, 0.5, 1.0]).forEach { lhs, rhs in
            XCTAssertEqual(lhs, rhs, accuracy: 1e-6)
        }
    }

    func testRoundAndBitDepth() {
        XCTAssertEqual(LUTMath.roundToNearest(5.3, nearest: 0.5), 5.0, accuracy: 1e-10)
        XCTAssertEqual(LUTMath.maxInteger(bitDepth: 8), 255)
    }

    func testStringHelpers() {
        let components = LUTStringHelper.componentsSeparatedByWhitespace(" 1  2  3 ")
        XCTAssertEqual(components, ["1", "2", "3"])

        let lines = ["# comment", "0.0 0.1 0.2", "junk"]
        XCTAssertEqual(LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines, valueCount: 3), 1)
        XCTAssertNil(LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines, valueCount: 4))

        XCTAssertEqual(LUTStringHelper.stringIsValidNumber("-1.23"), true)
        XCTAssertEqual(LUTStringHelper.stringIsValidNumber("abc"), false)
    }

    func testConcurrentRectLoopVisitsAllPoints() {
        let width = 4
        let height = 3
        let storage = ThreadSafeStringSet()

        LUTUtility.concurrentRectLoop(width: width, height: height) { x, y in
            storage.insert("\(x)-\(y)")
        }

        let visited = storage.snapshot()
        XCTAssertEqual(visited.count, width * height)
        for x in 0..<width {
            for y in 0..<height {
                XCTAssertTrue(visited.contains("\(x)-\(y)"))
            }
        }
    }

    func testProportionalScaling() {
        let current = CGSize(width: 400, height: 200)
        let target = CGSize(width: 100, height: 50)
        let scaled = LUTUtility.proportionallyScaledSize(current: current, target: target)
        XCTAssertEqual(scaled.width, 100, accuracy: 1e-6)
        XCTAssertEqual(scaled.height, 50, accuracy: 1e-6)

        let tallTarget = CGSize(width: 50, height: 200)
        let scaledTall = LUTUtility.proportionallyScaledSize(current: current, target: tallTarget)
        XCTAssertEqual(scaledTall.width, 50, accuracy: 1e-6)
        XCTAssertEqual(scaledTall.height, 25, accuracy: 1e-6)
    }
}

    private final class ThreadSafeStringSet: @unchecked Sendable {
        private var values: Set<String> = []
        private let lock = NSLock()

        func insert(_ value: String) {
            lock.lock()
            values.insert(value)
            lock.unlock()
        }

        func snapshot() -> Set<String> {
            lock.lock()
            let current = values
            lock.unlock()
            return current
        }
    }
