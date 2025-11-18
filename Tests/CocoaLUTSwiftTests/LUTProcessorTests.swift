import XCTest
@testable import CocoaLUTSwift

@MainActor
final class LUTProcessorTests: XCTestCase {
    private func makeIdentityLUT(size: Int = 2) -> LUT {
        LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
    }

    func testFactoryConfiguresProcessor() {
        let lut = makeIdentityLUT()
        let processor = LUTProcessor.processor(for: lut, completionHandler: nil, cancelHandler: nil)

        XCTAssertNotNil(processor.lut)
        XCTAssertTrue(processor.lut?.equals(lut) ?? false)
        XCTAssertEqual(processor.progress, 0)
        XCTAssertFalse(processor.cancelled)
        XCTAssertNil(processor.progressDescription)
    }

    func testCancelMarksProcessorAndDescription() {
        let processor = LUTProcessor.processor(for: makeIdentityLUT(), completionHandler: nil, cancelHandler: nil)

        processor.cancel()

        XCTAssertTrue(processor.cancelled)
        XCTAssertEqual(processor.progressDescription, "Canceling...")
        XCTAssertEqual(processor.progress, 0)
    }

    func testCheckCancellationTriggersHandlerOnce() {
        var cancelCount = 0
        let processor = LUTProcessor.processor(for: makeIdentityLUT()) { _ in } cancelHandler: {
            cancelCount += 1
        }

        processor.cancel()

        XCTAssertTrue(processor.checkCancellation())
        XCTAssertEqual(cancelCount, 1)

        XCTAssertTrue(processor.checkCancellation())
        XCTAssertEqual(cancelCount, 1)
    }

    func testCompletedWithLUTInvokesCompletionOnMainActor() {
        let lut = makeIdentityLUT(size: 4)
        var completionResult: LUT?
        let processor = LUTProcessor.processor(for: makeIdentityLUT(), completionHandler: { completedLUT in
            completionResult = completedLUT
        }, cancelHandler: nil)

        processor.process()
        processor.completed(with: lut)

        XCTAssertEqual(processor.progress, 1)
        XCTAssertTrue(completionResult?.equals(lut) ?? false)
    }

    func testSetProgressNormalizesAcrossSections() {
        let processor = LUTProcessor.processor(for: makeIdentityLUT(), completionHandler: nil, cancelHandler: nil)

        processor.setProgress(0.5, section: 2, of: 4)

        XCTAssertEqual(processor.progress, 0.375, accuracy: 1e-6)
    }
}
