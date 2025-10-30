#if canImport(AppKit)
import AppKit

public final class LUT1DGraphView: NSView {
    public enum Interpolation: Int {
        case linear
    }

    public var lut: LUT1D? {
        didSet {
            cachedRange = computeRange(for: lut)
            needsDisplay = true
        }
    }

    public var interpolation: Interpolation = .linear {
        didSet { needsDisplay = true }
    }

    public private(set) var minimumOutputValue: Double = 0
    public private(set) var maximumOutputValue: Double = 1

    private var cachedRange: (min: Double, max: Double) = (0, 1) {
        didSet {
            minimumOutputValue = cachedRange.min
            maximumOutputValue = cachedRange.max
        }
    }

    public override var isOpaque: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)

        guard let lut else { return }

        drawGrid(in: context, divisions: min(lut.size, 64))
        drawIdentity(in: context)
        if interpolation == .linear {
            drawCurves(for: lut, in: context)
        }
    }

    private func computeRange(for lut: LUT1D?) -> (Double, Double) {
        guard let lut else { return (0, 1) }
        let minValue = lut.minimumOutputValue()
        let maxValue = lut.maximumOutputValue()
        if minValue == maxValue {
            return (minValue, maxValue == 0 ? 1 : maxValue)
        }
        return (minValue, maxValue)
    }

    private func drawGrid(in context: CGContext, divisions: Int) {
        guard divisions > 1 else { return }
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(NSColor(calibratedWhite: 0.85, alpha: 1).cgColor)
        let strokeWidth = max(1.0 / (window?.backingScaleFactor ?? 1), 0.5)
        context.setLineWidth(strokeWidth)

        let stepX = bounds.width / CGFloat(divisions - 1)
        let stepY = bounds.height / CGFloat(divisions - 1)

        for index in 0..<divisions {
            let x = bounds.minX + CGFloat(index) * stepX
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
        }

        for index in 0..<divisions {
            let y = bounds.minY + CGFloat(index) * stepY
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }

        context.strokePath()
    }

    private func drawIdentity(in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(NSColor(calibratedWhite: 0.6, alpha: 1).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        context.strokePath()
    }

    private func drawCurves(for lut: LUT1D, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let redPath = NSBezierPath()
        let greenPath = NSBezierPath()
        let bluePath = NSBezierPath()

        for index in 0..<lut.size {
            let xPosition = position(forIndex: index, size: lut.size)
            let color = lut.colorAt(index: index)
            let redY = position(forValue: color.red)
            let greenY = position(forValue: color.green)
            let blueY = position(forValue: color.blue)

            appendPoint(CGPoint(x: xPosition, y: redY), to: redPath, at: index)
            appendPoint(CGPoint(x: xPosition, y: greenY), to: greenPath, at: index)
            appendPoint(CGPoint(x: xPosition, y: blueY), to: bluePath, at: index)
        }

        NSColor.red.setStroke()
        redPath.lineWidth = 2
        redPath.stroke()

        NSColor.green.setStroke()
        greenPath.lineWidth = 2
        greenPath.stroke()

        NSColor.blue.setStroke()
        bluePath.lineWidth = 2
        bluePath.stroke()

        if lut.size <= 64 {
            drawControlPoints(for: lut, in: context)
        }
    }

    private func drawControlPoints(for lut: LUT1D, in context: CGContext) {
        context.setFillColor(NSColor.red.cgColor)
        for index in 0..<lut.size {
            let point = CGPoint(x: position(forIndex: index, size: lut.size), y: position(forValue: lut.valueAtR(index)))
            drawPoint(point, in: context)
        }

        context.setFillColor(NSColor.green.cgColor)
        for index in 0..<lut.size {
            let point = CGPoint(x: position(forIndex: index, size: lut.size), y: position(forValue: lut.valueAtG(index)))
            drawPoint(point, in: context)
        }

        context.setFillColor(NSColor.blue.cgColor)
        for index in 0..<lut.size {
            let point = CGPoint(x: position(forIndex: index, size: lut.size), y: position(forValue: lut.valueAtB(index)))
            drawPoint(point, in: context)
        }
    }

    private func drawPoint(_ point: CGPoint, in context: CGContext) {
        let size = CGSize(width: 4, height: 4)
        let rect = CGRect(origin: CGPoint(x: point.x - size.width / 2,
                                          y: point.y - size.height / 2),
                          size: size)
        context.fillEllipse(in: rect)
    }

    private func position(forIndex index: Int, size: Int) -> CGFloat {
        guard size > 1 else { return bounds.midX }
        let t = CGFloat(index) / CGFloat(size - 1)
        return bounds.minX + t * bounds.width
    }

    private func position(forValue value: Double) -> CGFloat {
        let minValue = min(cachedRange.min, 0)
        let maxValue = max(cachedRange.max, 1)
        let range = max(maxValue - minValue, Double.ulpOfOne)
        let normalized = (value - minValue) / range
        return bounds.minY + CGFloat(normalized) * bounds.height
    }

    private func appendPoint(_ point: CGPoint, to path: NSBezierPath, at index: Int) {
        if index == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
    }
}
#endif
