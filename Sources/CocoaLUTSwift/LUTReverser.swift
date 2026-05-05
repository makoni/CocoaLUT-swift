import Foundation

@MainActor
open class LUTReverser: LUTProcessor {
    public required init() {
        super.init()
    }

    open override func process() {
        super.process()
        guard let inputLUT = lut else {
            didCancel()
            return
        }

        guard !checkCancellation() else { return }

        let output = reverse(inputLUT)
        completed(with: output)
    }

    /// Default implementation returns the input LUT unchanged.
    /// Subclasses can override to supply actual reversal logic.
    open func reverse(_ lut: LUT) -> LUT {
        lut
    }
}
