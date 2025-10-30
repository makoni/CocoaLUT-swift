#if canImport(AppKit)
import AppKit

@MainActor
public final class LUTPreviewImageGenerator {
    public var lut: LUT

    public init(lut: LUT3D) {
        self.lut = lut.asLUT()
    }

    public init(lut: LUT) {
        self.lut = lut
    }

    public func render(from image: NSImage, targetSize: CGSize) -> NSImage? {
        let scaled = LUTUtility.proportionallyScaledSize(current: image.size, target: targetSize)
        guard scaled.width > 0, scaled.height > 0 else { return nil }

        let processedImage = lut.process(nsImage: image, renderPath: .coreImage) ?? image

        let output = NSImage(size: scaled)
        output.lockFocus()
        defer { output.unlockFocus() }

        let destinationRect = NSRect(origin: .zero, size: scaled)
        let sourceRect = NSRect(origin: .zero, size: image.size)
        image.draw(in: destinationRect,
                   from: sourceRect,
                   operation: .copy,
                   fraction: 1,
                   respectFlipped: false,
                   hints: nil)

        NSGraphicsContext.saveGraphicsState()
        let maskPath = NSBezierPath()
        maskPath.move(to: .zero)
        maskPath.line(to: NSPoint(x: 0, y: scaled.height))
        maskPath.line(to: NSPoint(x: scaled.width, y: scaled.height))
        maskPath.close()
        maskPath.addClip()

        processedImage.draw(in: destinationRect,
                            from: sourceRect,
                            operation: .sourceOver,
                            fraction: 1,
                            respectFlipped: false,
                            hints: nil)
        NSGraphicsContext.restoreGraphicsState()

        let diagonal = NSBezierPath()
        diagonal.move(to: .zero)
        diagonal.line(to: NSPoint(x: scaled.width, y: scaled.height))
        NSColor(calibratedWhite: 1, alpha: 0.5).setStroke()
        diagonal.lineWidth = 2
        diagonal.stroke()

        return output
    }

    public func draw(from image: NSImage,
                     targetSize: CGSize,
                     in context: NSGraphicsContext) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.current = previous }

        if let rendered = render(from: image, targetSize: targetSize) {
            rendered.draw(at: .zero,
                          from: NSRect(origin: .zero, size: rendered.size),
                          operation: .copy,
                          fraction: 1)
        }
    }
}
#endif
