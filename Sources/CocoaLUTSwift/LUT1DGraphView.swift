#if canImport(AppKit)
import AppKit

@MainActor
public final class LUT1DGraphView: NSView {
    public enum Interpolation: Int, CaseIterable, Sendable {
        case linear

        public var displayName: String {
            switch self {
            case .linear: return "Linear"
            }
        }
    }

    public var lut: LUT1D? {
        didSet {
            cachedRange = computeRange(for: lut)
            if let lut {
                onLUTDidChange?(lut)
            }
            needsDisplay = true
        }
    }

    public var interpolation: Interpolation = .linear {
        didSet {
            if interpolation != oldValue {
                needsDisplay = true
            }
        }
    }

    public private(set) var minimumOutputValue: Double = 0
    public private(set) var maximumOutputValue: Double = 1

    /// Mirrors ObjC `LUT1DGraphView.mousePoint` (LUT1DGraphView.h:20).
    /// Position in window coordinates as delivered by `mouseMoved:`.
    public var mousePoint: NSPoint = .zero {
        didSet { needsDisplay = true }
    }
    public private(set) var mouseIsIn: Bool = false

    /// Fires whenever a non-nil LUT is assigned. Mirrors ObjC `lutDidChange`.
    public var onLUTDidChange: ((LUT1D) -> Void)?

    private var trackingArea: NSTrackingArea?
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
        installTrackingArea()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        installTrackingArea()
    }

    private func installTrackingArea() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseMoved(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        mousePoint = local
    }

    public override func mouseEntered(with event: NSEvent) {
        mouseIsIn = true
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        mouseIsIn = false
        needsDisplay = true
    }

    /// Mirrors ObjC `-indexLUTColorAndIdentityLUTColorFromCurrentMousePoint`
    /// but returns a typed tuple. Returns `nil` when no LUT is set.
    public func lookupColors(at point: NSPoint) -> (output: LUTColor, identity: LUTColor)? {
        guard let lut else { return nil }
        let xOrigin = bounds.origin.x
        let pixelWidth = bounds.size.width
        guard pixelWidth > 0 else { return nil }

        let xPosition = LUTMath.clamp(Double(point.x), lower: 0, upper: Double(pixelWidth))
        let interpolatedIndex = LUTMath.remapNoError(xPosition,
                                                     inputLow: Double(xOrigin),
                                                     inputHigh: Double(pixelWidth - xOrigin),
                                                     outputLow: 0,
                                                     outputHigh: Double(lut.size - 1))
        let output = lut.colorAtInterpolated(red: interpolatedIndex,
                                             green: interpolatedIndex,
                                             blue: interpolatedIndex)
        let identity = lut.identityColorAtInterpolated(red: interpolatedIndex,
                                                       green: interpolatedIndex,
                                                       blue: interpolatedIndex)
        return (output, identity)
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

        if mouseIsIn {
            drawOverlay(for: lut, in: context, at: mousePoint, thickness: 2.0, opacity: 0.8)
        }
    }

    /// Mirrors ObjC `-drawOverlayInContext:inRect:withPoint:thickness:opacity:`
    /// (LUT1DGraphView.m:179-251).
    private func drawOverlay(for lut: LUT1D,
                             in context: CGContext,
                             at point: NSPoint,
                             thickness: CGFloat,
                             opacity: CGFloat) {
        let xOrigin = bounds.origin.x
        let yOrigin = bounds.origin.y
        let pixelWidth = bounds.size.width
        let pixelHeight = bounds.size.height
        let xPosition = round(point.x)
        if xPosition < xOrigin || xPosition > xOrigin + pixelWidth {
            return
        }

        let interpolatedIndex = LUTMath.remapNoError(Double(xPosition),
                                                     inputLow: Double(xOrigin),
                                                     inputHigh: Double(pixelWidth - xOrigin),
                                                     outputLow: 0,
                                                     outputHigh: Double(lut.size - 1))
        let color = lut.colorAtInterpolated(red: interpolatedIndex,
                                            green: interpolatedIndex,
                                            blue: interpolatedIndex)
        let lower = min(cachedRange.min, 0)
        let upper = max(cachedRange.max, 1)
        let yMin = Double(yOrigin)
        let yMax = Double(yOrigin + pixelHeight)
        let redY = round(LUTMath.remapNoError(color.red, inputLow: lower, inputHigh: upper, outputLow: yMin, outputHigh: yMax))
        let greenY = round(LUTMath.remapNoError(color.green, inputLow: lower, inputHigh: upper, outputLow: yMin, outputHigh: yMax))
        let blueY = round(LUTMath.remapNoError(color.blue, inputLow: lower, inputHigh: upper, outputLow: yMin, outputHigh: yMax))

        context.saveGState()
        defer { context.restoreGState() }
        context.setLineWidth(thickness)

        context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: opacity * 0.5)
        context.beginPath()
        context.move(to: CGPoint(x: xPosition, y: yOrigin))
        context.addLine(to: CGPoint(x: xPosition, y: yOrigin + pixelHeight))
        context.strokePath()

        context.setStrokeColor(red: 1, green: 0, blue: 0, alpha: opacity)
        context.beginPath()
        context.move(to: CGPoint(x: xOrigin, y: redY))
        context.addLine(to: CGPoint(x: xOrigin + pixelWidth, y: redY))
        context.strokePath()

        context.setStrokeColor(red: 0, green: 1, blue: 0, alpha: opacity)
        context.beginPath()
        context.move(to: CGPoint(x: xOrigin, y: greenY))
        context.addLine(to: CGPoint(x: xOrigin + pixelWidth, y: greenY))
        context.strokePath()

        context.setStrokeColor(red: 0, green: 0, blue: 1, alpha: opacity)
        context.beginPath()
        context.move(to: CGPoint(x: xOrigin, y: blueY))
        context.addLine(to: CGPoint(x: xOrigin + pixelWidth, y: blueY))
        context.strokePath()
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

/// Mirrors ObjC `LUT1DGraphViewController` (LUT1DGraphView.h:33-45).
/// Shows the LUT in an embedded `LUT1DGraphView` and exposes input/output colors
/// at the current mouse position via callback bindings.
@MainActor
public final class LUT1DGraphViewController: NSViewController {
    public private(set) var graphView: LUT1DGraphView

    /// Identity colour at the current mouse position. Updated on every mouse move.
    public private(set) var inputColor: NSColor?

    /// Transformed (LUT) colour at the current mouse position.
    public private(set) var outputColor: NSColor?

    /// Fired whenever the mouse moves and `inputColor`/`outputColor` change.
    public var onColorsAtMousePointChanged: ((_ input: NSColor?, _ output: NSColor?) -> Void)?

    public init(graphView: LUT1DGraphView = LUT1DGraphView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))) {
        self.graphView = graphView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = graphView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        graphView.onLUTDidChange = { [weak self] _ in
            self?.refreshColorsAtMousePoint()
        }
    }

    public func setLUT(_ lut: LUT1D) {
        graphView.lut = lut
    }

    public func setInterpolation(_ interpolation: LUT1DGraphView.Interpolation) {
        graphView.interpolation = interpolation
    }

    /// Recomputes `inputColor`/`outputColor` for the graph view's current mouse point.
    /// Mirrors ObjC `-mouseMoved` (LUT1DGraphView.m:41-49) — typically invoked on a
    /// mouse-move callback wired from outside.
    public func refreshColorsAtMousePoint() {
        guard let lookup = graphView.lookupColors(at: graphView.mousePoint) else {
            inputColor = nil
            outputColor = nil
            onColorsAtMousePointChanged?(nil, nil)
            return
        }
        inputColor = lookup.identity.systemColor
        outputColor = lookup.output.systemColor
        onColorsAtMousePointChanged?(inputColor, outputColor)
    }
}
#endif
