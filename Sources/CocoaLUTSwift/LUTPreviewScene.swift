#if canImport(SceneKit) && canImport(AppKit)
import AppKit
import SceneKit

@MainActor
public final class LUTPreviewScene: SCNScene {
    public final class LUTColorNode: SCNNode {
        public var identityColor: LUTColor
        public var transformedColor: LUTColor {
            didSet { updatePosition() }
        }
        public var r: Int
        public var g: Int
        public var b: Int

        public var animationPercentage: Double = 0 {
            didSet {
                let clamped = min(max(animationPercentage, 0), 1)
                if clamped != animationPercentage {
                    animationPercentage = clamped
                    return
                }
                updatePosition()
            }
        }

        init(identityColor: LUTColor,
             transformedColor: LUTColor,
             r: Int,
             g: Int,
             b: Int,
             geometry: SCNGeometry?) {
            self.identityColor = identityColor
            self.transformedColor = transformedColor
            self.r = r
            self.g = g
            self.b = b
            super.init()
            self.geometry = geometry
            updatePosition()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func updatePosition() {
            let x = Self.lerp(identityColor.red, transformedColor.red, t: animationPercentage)
            let y = Self.lerp(identityColor.green, transformedColor.green, t: animationPercentage)
            let z = Self.lerp(identityColor.blue, transformedColor.blue, t: animationPercentage)
            position = SCNVector3(Float(x), Float(y), Float(z))
        }

        private static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
            let clamped = min(max(t, 0), 1)
            return a + (b - a) * clamped
        }
    }

    public private(set) var dotGroup = SCNNode()
    public private(set) var cubeOutline: SCNNode?
    public private(set) var axes: SCNNode?

    public private(set) var lut: LUT3D
    private var outputRange: (min: Double, max: Double)
    private var internalAnimationPercentage: Double = 0

    public var animationPercentage: Double {
        get { internalAnimationPercentage }
        set {
            let clamped = min(max(newValue, 0), 1)
            internalAnimationPercentage = clamped
            for case let node as LUTColorNode in dotGroup.childNodes {
                node.animationPercentage = clamped
            }
        }
    }

    private init(lut: LUT3D,
                 outputRange: (Double, Double)) {
        self.lut = lut
        self.outputRange = outputRange
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    public func sceneWithUpdated(lut newLUT: LUT3D) -> LUTPreviewScene {
        let prepared = Self.prepare(newLUT)
        let base = prepared.asLUT()
        let newRange = (base.minimumOutputValue(), base.maximumOutputValue())

        let sizeChanged = prepared.size != lut.size
        let rangeDrift = abs(newRange.0 - outputRange.min) > 1.0 || abs(newRange.1 - outputRange.max) > 1.0

        if sizeChanged || rangeDrift {
            return Self.scene(for: newLUT)
        }

        for case let node as LUTColorNode in dotGroup.childNodes {
            let transformed = prepared.colorAt(r: node.r, g: node.g, b: node.b)
            node.transformedColor = transformed
        }

        lut = prepared
        outputRange = newRange
        animationPercentage = animationPercentage
        return self
    }

    @discardableResult
    public func sceneWithUpdated(lut newLUT: LUT) -> LUTPreviewScene {
        sceneWithUpdated(lut: LUT3D(lattice: newLUT))
    }

    public static func scene(for lut: LUT3D) -> LUTPreviewScene {
        let prepared = prepare(lut)
        let base = prepared.asLUT()
        let range = (base.minimumOutputValue(), base.maximumOutputValue())
        let scene = LUTPreviewScene(lut: prepared, outputRange: range)
        scene.buildNodes(for: prepared)
        return scene
    }

    public static func scene(for lut: LUT) -> LUTPreviewScene {
        scene(for: LUT3D(lattice: lut))
    }

    private func buildNodes(for lut: LUT3D) {
    let radius = CGFloat(0.013 * max(lut.inputUpperBound - lut.inputLowerBound, 1))
    let dotGroup = SCNNode()
        lut.loop { r, g, b in
            let identity = identityColor(for: (r, g, b), in: lut)
            let transformed = lut.colorAt(r: r, g: g, b: b)
            let geometry = SCNSphere(radius: radius)
            geometry.firstMaterial?.diffuse.contents = NSColor(calibratedRed: CGFloat(identity.red),
                                                               green: CGFloat(identity.green),
                                                               blue: CGFloat(identity.blue),
                                                               alpha: 1)
            let node = LUTColorNode(identityColor: identity,
                                     transformedColor: transformed,
                                     r: r,
                                     g: g,
                                     b: b,
                                     geometry: geometry)
            node.animationPercentage = internalAnimationPercentage
            dotGroup.addChildNode(node)
        }

        self.dotGroup.removeFromParentNode()
        self.dotGroup = dotGroup
        rootNode.addChildNode(dotGroup)
    }

    private static func prepare(_ lut: LUT3D) -> LUT3D {
        let maxSize = min(18, lut.size)
        if lut.size == maxSize {
            return lut
        }
        return lut.resized(to: maxSize)
    }

    private func identityColor(for indices: (Int, Int, Int), in lut: LUT3D) -> LUTColor {
        let sizeRange = Double(lut.size - 1)
        let lower = lut.inputLowerBound
        let upper = lut.inputUpperBound
        let red = LUTMath.remapNoError(Double(indices.0),
                                       inputLow: 0,
                                       inputHigh: sizeRange,
                                       outputLow: lower,
                                       outputHigh: upper)
        let green = LUTMath.remapNoError(Double(indices.1),
                                         inputLow: 0,
                                         inputHigh: sizeRange,
                                         outputLow: lower,
                                         outputHigh: upper)
        let blue = LUTMath.remapNoError(Double(indices.2),
                                        inputLow: 0,
                                        inputHigh: sizeRange,
                                        outputLow: lower,
                                        outputHigh: upper)
        return LUTColor.color(red: red, green: green, blue: blue)
    }
}
#endif
