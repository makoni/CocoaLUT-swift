import Testing
@testable import CocoaLUTSwift

@MainActor
@Suite(.serialized)
struct LUTReverserTests {
    @Test
    func testProcessReturnsInputWhenNoReversalLogicProvided() async {
        let input = LUT.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        var completedLUT: LUT?
        var reverser: LUTReverser?

        await confirmation("reverse completes") { confirmation in
            reverser = LUTReverser.processor(for: input) { lut in
                completedLUT = lut
                confirmation()
            } cancelHandler: {
                Issue.record(Comment("Unexpected cancellation"))
            }

            reverser?.process()
        }

        guard let reverser else {
            Issue.record(Comment("Reverser was not created"))
            return
        }

        #expect(reverser.progress == 1)
        #expect(completedLUT?.equals(input) == true)
    }

    @Test
    func testProcessHonorsCancellation() async {
        let input = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        var completionCalled = false
        var reverser: LUTReverser?

        await confirmation("cancel handler invoked") { confirmation in
            reverser = LUTReverser.processor(for: input) { _ in
                completionCalled = true
            } cancelHandler: {
                confirmation()
            }

            reverser?.cancel()
            reverser?.process()
        }

        guard let reverser else {
            Issue.record(Comment("Reverser was not created"))
            return
        }

        #expect(reverser.cancelled)
        #expect(!completionCalled)
        #expect(reverser.progress == 0)
    }
}
