import CoreGraphics
import Foundation
import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTHelperTests {
    @Test
    func testClampVariants() {
        #expect(LUTMath.clamp(1.5, lower: 0, upper: 1) == 1)
        #expect(LUTMath.clamp01(-0.5) == 0)
        #expect(LUTMath.clampLowerBound(-1, lowerBound: 0) == 0)
        #expect(LUTMath.clampUpperBound(5, upperBound: 1) == 1)
        #expect(LUTMath.outOfBounds(5, lowerBound: 0, upperBound: 1, inclusive: true))
        #expect(!LUTMath.outOfBounds(1, lowerBound: 0, upperBound: 1, inclusive: true))
    }

    @Test
    func testRemapVariants() {
        #expect(LUTMath.remapNoError(0.5, inputLow: 0, inputHigh: 1, outputLow: 0, outputHigh: 10) == 5)
        #expect(abs(LUTMath.remapInt01(128, maxValue: 255) - 0.5019607843137255) < 1e-6)
        #expect(LUTMath.remapInt01(8, bitDepthMax: 15) == 8.0 / 15.0)
        #expect(LUTMath.lerp(0, 10, t: 0.5) == 5)
        #expect(abs(LUTMath.smoothstep(0, 1, percentage: 0.5) - 0.5) < 1e-6)
        #expect(abs(LUTMath.smootherstep(0, 1, percentage: 0.5) - 0.5) < 1e-6)
    }

    @Test
    func testIndicesGeneration() {
        #expect(LUTMath.indicesIntegerArray(start: 0, end: 4, count: 5) == [0, 1, 2, 3, 4])
        #expect(LUTMath.indicesIntegerArrayLegacy(start: 0, end: 4, count: 5) == [0, 1, 3, 4, 4])
        let doubles = LUTMath.indicesDoubleArray(start: 0, end: 1, count: 3)
        #expect(doubles.count == 3)
        zip(doubles, [0.0, 0.5, 1.0]).forEach { lhs, rhs in
            #expect(abs(lhs - rhs) < 1e-6)
        }
    }

    @Test
    func testRoundAndBitDepth() {
        #expect(abs(LUTMath.roundToNearest(5.3, nearest: 0.5) - 5.0) < 1e-10)
        #expect(LUTMath.maxInteger(bitDepth: 8) == 255)
    }

    @Test
    func testStringHelpers() {
        let components = LUTStringHelper.componentsSeparatedByWhitespace(" 1  2  3 ")
        #expect(components == ["1", "2", "3"])

        let lines = ["# comment", "0.0 0.1 0.2", "junk"]
        #expect(LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines, valueCount: 3) == 1)
        #expect(LUTStringHelper.findFirstLUTLineWithWhitespaceSeparators(in: lines, valueCount: 4) == nil)

        #expect(LUTStringHelper.stringIsValidNumber("-1.23") == true)
        #expect(LUTStringHelper.stringIsValidNumber("abc") == false)
    }

    @Test
    func testConcurrentRectLoopVisitsAllPoints() {
        let width = 4
        let height = 3
        let storage = ThreadSafeStringSet()

        LUTUtility.concurrentRectLoop(width: width, height: height) { x, y in
            storage.insert("\(x)-\(y)")
        }

        let visited = storage.snapshot()
        #expect(visited.count == width * height)
        for x in 0..<width {
            for y in 0..<height {
                #expect(visited.contains("\(x)-\(y)"))
            }
        }
    }

    @Test
    func testProportionalScaling() {
        let current = CGSize(width: 400, height: 200)
        let target = CGSize(width: 100, height: 50)
        let scaled = LUTUtility.proportionallyScaledSize(current: current, target: target)
        #expect(abs(scaled.width - 100) < 1e-6)
        #expect(abs(scaled.height - 50) < 1e-6)

        let tallTarget = CGSize(width: 50, height: 200)
        let scaledTall = LUTUtility.proportionallyScaledSize(current: current, target: tallTarget)
        #expect(abs(scaledTall.width - 50) < 1e-6)
        #expect(abs(scaledTall.height - 25) < 1e-6)
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
