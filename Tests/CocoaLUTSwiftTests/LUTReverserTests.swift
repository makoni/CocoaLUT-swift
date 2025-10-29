import XCTest
@testable import CocoaLUT_swift

@MainActor
final class LUTReverserTests: XCTestCase {
    func testProcessReturnsInputWhenNoReversalLogicProvided() {
        let input = LUT.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        let completionExpectation = expectation(description: "completion")
        var completedLUT: LUT?

        let reverser = LUTReverser.processor(for: input) { lut in
            completedLUT = lut
            completionExpectation.fulfill()
        } cancelHandler: {
            XCTFail("Unexpected cancellation")
        }

        reverser.process()

        wait(for: [completionExpectation], timeout: 0.1)
        XCTAssertEqual(reverser.progress, 1)
        XCTAssertTrue(completedLUT?.equals(input) ?? false)
    }

    func testProcessHonorsCancellation() {
        let input = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let cancelExpectation = expectation(description: "cancelled")
        cancelExpectation.expectedFulfillmentCount = 1
        var completionCalled = false

        let reverser = LUTReverser.processor(for: input) { _ in
            completionCalled = true
        } cancelHandler: {
            cancelExpectation.fulfill()
        }

        reverser.cancel()
        reverser.process()

        wait(for: [cancelExpectation], timeout: 0.1)
        XCTAssertTrue(reverser.cancelled)
        XCTAssertFalse(completionCalled)
        XCTAssertEqual(reverser.progress, 0)
    }
}
