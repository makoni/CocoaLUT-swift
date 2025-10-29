import Foundation

@MainActor
open class LUTProcessor {
    public var lut: LUT?
    public var progressDescription: String?
    public var completionHandler: ((LUT) -> Void)?
    public var cancelHandler: (() -> Void)?

    private var progressValue: Float = 0
    public var progress: Float {
        get { progressValue }
        set { progressValue = newValue }
    }

    public var cancelled: Bool = false

    private var startTime: Date?
    private var hasCalledCancelHandler = false

    public required init() {}

    public static func processor(for lut: LUT,
                                 completionHandler: ((LUT) -> Void)? = nil,
                                 cancelHandler: (() -> Void)? = nil) -> Self {
        let processor = Self.init()
        processor.lut = lut
        processor.completionHandler = completionHandler
        processor.cancelHandler = cancelHandler
        return processor
    }

    open func process() {
        startTime = Date()
    }

    public func cancel() {
        cancelled = true
        progressDescription = "Canceling..."
    }

    open func completed(with lut: LUT) {
        progress = 1
        if let startTime {
            let duration = -startTime.timeIntervalSinceNow
            NSLog("-> Processor finished in %fs", duration)
        }
        completionHandler?(lut)
    }

    @discardableResult
    public func checkCancellation() -> Bool {
        guard cancelled else { return false }
        if !hasCalledCancelHandler {
            hasCalledCancelHandler = true
            didCancel()
        }
        return true
    }

    open func didCancel() {
        cancelHandler?()
    }

    public func setProgress(_ progress: Float, section: Int, of sectionCount: Int) {
        guard sectionCount > 0 else {
            self.progress = progress
            return
        }
        let normalized = (progress / Float(sectionCount)) + ((Float(section) - 1) / Float(sectionCount))
        self.progress = normalized
    }
}
