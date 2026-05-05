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
        // Mirrors ObjC `-drawPreviewImageFromImage:resizedToSize:inContext:`
        // (LUTPreviewImageGenerator.m:23-85) — uses `CGImageMaskCreate` +
        // `CGImageCreateWithMask` for bit-identical output rather than NSBezierPath
        // clipping.
        let scaled = LUTUtility.proportionallyScaledSize(current: image.size, target: targetSize)
        let pixelWidth = Int(round(scaled.width))
        let pixelHeight = Int(round(scaled.height))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let processedImage = lut.process(nsImage: image, renderPath: .coreImage) ?? image

        guard let baseCGImage = Self.cgImage(from: image),
              let processedCGImage = Self.cgImage(from: processedImage) else {
            return nil
        }

        guard let mask = Self.makeDiagonalMask(width: pixelWidth, height: pixelHeight),
              let maskedProcessed = processedCGImage.masking(mask) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: pixelWidth,
                                      height: pixelHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        let destination = CGRect(origin: .zero,
                                 size: CGSize(width: pixelWidth, height: pixelHeight))
        context.draw(baseCGImage, in: destination)
        context.draw(maskedProcessed, in: destination)

        context.setLineWidth(2)
        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.5).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: CGFloat(pixelWidth), y: CGFloat(pixelHeight)))
        context.strokePath()

        guard let composedCGImage = context.makeImage() else {
            return nil
        }
        return NSImage(cgImage: composedCGImage,
                       size: NSSize(width: pixelWidth, height: pixelHeight))
    }

    /// Renders the triangle mask (vertices (0,0)→(0,h)→(w,h)) as a single-channel
    /// 8-bit grayscale CGImage and wraps it via `CGImageMaskCreate`.
    /// Mirrors ObjC `LUTPreviewImageGenerator.m:44-68`.
    private static func makeDiagonalMask(width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width
        let dataSize = bytesPerRow * height
        // CGImageMaskCreate semantics: sample 0 → paint source, 255 → don't paint.
        // We want the upper-left triangle (matching ObjC NSBezierPath at (0,0),
        // (0,h), (w,h) in y-up) to paint the processed image, so make the triangle
        // BLACK (0) on a WHITE (255) background.
        var pixelData = Data(repeating: 0xFF, count: dataSize)
        pixelData.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for row in 0..<height {
                let limit = max(0, height - 1 - row)
                let span = min(limit + 1, width)
                for col in 0..<span {
                    base[row * bytesPerRow + col] = 0x00
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        guard let imageRef = CGImage(width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bitsPerPixel: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                     provider: provider,
                                     decode: nil,
                                     shouldInterpolate: true,
                                     intent: .defaultIntent) else {
            return nil
        }
        return CGImage(maskWidth: imageRef.width,
                       height: imageRef.height,
                       bitsPerComponent: imageRef.bitsPerComponent,
                       bitsPerPixel: imageRef.bitsPerPixel,
                       bytesPerRow: imageRef.bytesPerRow,
                       provider: imageRef.dataProvider!,
                       decode: nil,
                       shouldInterpolate: true)
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
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
