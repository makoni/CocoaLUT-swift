#if canImport(AppKit)
import AppKit
import QuartzCore

@MainActor
public final class LUTPreviewView: NSView {
    public var lut: LUT? {
        didSet {
            cachedProcessedImage = nil
            scheduleImageUpdate()
        }
    }

    private var internalMaskAmount: CGFloat = 0.5
    public var maskAmount: CGFloat {
        get { internalMaskAmount }
        set {
            let clamped = max(0, min(newValue, 1))
            guard clamped != internalMaskAmount else { return }
            internalMaskAmount = clamped
            updateMaskFrames()
            needsLayout = true
        }
    }

    public var previewImage: NSImage? {
        didSet {
            if previewImage != nil {
                cachedProcessedImage = nil
            }
            scheduleImageUpdate()
        }
    }

    public private(set) var originalLayer = CALayer()
    public private(set) var processedLayer = CALayer()

    private let maskLayer = CALayer()
    private let processedContainerLayer = CALayer()
    private let borderLayer = CALayer()
    private var cachedProcessedImage: NSImage?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayers()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = self.bounds
        originalLayer.frame = bounds
        processedLayer.frame = bounds
        updateMaskFrames(within: bounds)
        CATransaction.commit()
    }

    private func configureLayers() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = NSColor.black.cgColor

        originalLayer.contentsGravity = .resizeAspect
        originalLayer.masksToBounds = true

        processedContainerLayer.masksToBounds = true

        processedLayer.contentsGravity = .resizeAspect
        processedLayer.masksToBounds = true

        maskLayer.backgroundColor = NSColor.white.cgColor
        maskLayer.anchorPoint = .zero
        maskLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "transform": NSNull()
        ]
        processedLayer.mask = maskLayer

        borderLayer.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.5).cgColor
        borderLayer.zPosition = 1

        layer?.addSublayer(originalLayer)
        processedContainerLayer.addSublayer(processedLayer)
        layer?.addSublayer(processedContainerLayer)
        layer?.addSublayer(borderLayer)
    }

    private func updateMaskFrames(within bounds: CGRect? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = bounds ?? self.bounds
        let maskWidth = max(bounds.width * maskAmount, 0)

        processedContainerLayer.frame = CGRect(x: bounds.minX,
                                               y: bounds.minY,
                                               width: maskWidth,
                                               height: bounds.height)

        maskLayer.frame = CGRect(x: 0,
                                 y: 0,
                                 width: maskWidth,
                                 height: bounds.height)

        let scale = window?.backingScaleFactor ?? 1
        let borderWidth = max(1.0 / scale, 1.0)
        borderLayer.frame = CGRect(x: max(maskWidth - borderWidth / 2, 0),
                                   y: 0,
                                   width: borderWidth,
                                   height: bounds.height)
        CATransaction.commit()
    }

    private func scheduleImageUpdate() {
        guard let image = previewImage else {
            originalLayer.contents = nil
            processedLayer.contents = nil
            cachedProcessedImage = nil
            return
        }

        originalLayer.contents = image

        if let cached = cachedProcessedImage {
            processedLayer.contents = cached
            return
        }

        guard let lut else {
            processedLayer.contents = image
            return
        }

        if let processed = lut.process(nsImage: image, renderPath: .coreImage)
            ?? lut.process(nsImage: image, renderPath: .direct) {
            cachedProcessedImage = processed
            processedLayer.contents = processed
        } else {
            processedLayer.contents = image
        }
        needsLayout = true
    }
}
#endif
