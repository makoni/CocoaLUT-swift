import Testing
@testable import CocoaLUTSwift

@MainActor

@Suite(.serialized)
struct LUTProcessorTests {
    private func makeIdentityLUT(size: Int = 2) -> LUT {
        LUT.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
    }

    @Test
    func testFactoryConfiguresProcessor() {
        let lut = makeIdentityLUT()
        let processor = LUTProcessor.processor(for: lut, completionHandler: nil, cancelHandler: nil)

        #expect(processor.lut != nil)
        #expect(processor.lut?.equals(lut) ?? false)
        #expect(processor.progress == 0)
        #expect(!processor.cancelled)
        #expect(processor.progressDescription == nil)
    }

    @Test
    func testCancelMarksProcessorAndDescription() {
        let processor = LUTProcessor.processor(for: makeIdentityLUT(), completionHandler: nil, cancelHandler: nil)

        processor.cancel()

        #expect(processor.cancelled)
        #expect(processor.progressDescription == "Canceling...")
        #expect(processor.progress == 0)
    }

    @Test
    func testCheckCancellationTriggersHandlerOnce() {
        var cancelCount = 0
        let processor = LUTProcessor.processor(for: makeIdentityLUT()) { _ in } cancelHandler: {
            cancelCount += 1
        }

        processor.cancel()

        #expect(processor.checkCancellation())
        #expect(cancelCount == 1)

        #expect(processor.checkCancellation())
        #expect(cancelCount == 1)
    }

    @Test
    func testCompletedWithLUTInvokesCompletionOnMainActor() {
        let lut = makeIdentityLUT(size: 4)
        var completionResult: LUT?
        let processor = LUTProcessor.processor(for: makeIdentityLUT(), completionHandler: { completedLUT in
            completionResult = completedLUT
        }, cancelHandler: nil)

        processor.process()
        processor.completed(with: lut)

        #expect(processor.progress == 1)
        #expect(completionResult?.equals(lut) ?? false)
    }

    @Test
    func testSetProgressNormalizesAcrossSections() {
        let processor = LUTProcessor.processor(for: makeIdentityLUT(), completionHandler: nil, cancelHandler: nil)

        processor.setProgress(0.5, section: 2, of: 4)

        #expect(abs(processor.progress - 0.375) < 1e-6)
    }
}
