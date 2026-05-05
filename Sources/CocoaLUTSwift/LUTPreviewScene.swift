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
        scene.buildOverlay(for: prepared)
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

    private func buildOverlay(for lut: LUT3D) {
        // Mirrors ObjC `+sceneForLUT:` (LUTPreviewScene.m:127-194) — match the radius
        // formula and add the cube grid + axes node.
        let span = max(lut.inputUpperBound - lut.inputLowerBound, 1)
        let outputSpan = max(outputRange.max - outputRange.min, 1)
        let dominantSpan = outputSpan > span ? outputSpan : span
        let radius = 0.013 * dominantSpan
        let axisLength = 1.2 * dominantSpan

        let cube = Self.cubeOutline(inputLowerBound: lut.inputLowerBound,
                                    inputUpperBound: lut.inputUpperBound,
                                    radius: radius / 2.0)
        cube.opacity = 0.3
        cubeOutline?.removeFromParentNode()
        cubeOutline = cube
        rootNode.addChildNode(cube)

        let axesNode = Self.axes(origin: SCNVector3Zero,
                                 length: axisLength,
                                 radius: radius / 2.0)
        axesNode.opacity = 0.5
        axes?.removeFromParentNode()
        axes = axesNode
        rootNode.addChildNode(axesNode)
    }

    /// Mirrors ObjC `+axesWithOrigin:length:radius:` (LUTPreviewScene.m:197-258).
    /// Three coloured cylinders aligned to X/Y/Z plus three cone pointers at the tips.
    private static func axes(origin: SCNVector3, length: Double, radius: Double) -> SCNNode {
        let parent = SCNNode()
        let pointerHeight = radius * 4.0
        let pointerOffset = pointerHeight / 2.0
        let halfPi = Double.pi / 2.0
        let pi = Double.pi

        func cylinder(color: NSColor) -> SCNCylinder {
            let geo = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
            geo.firstMaterial?.diffuse.contents = color
            return geo
        }

        func cone(color: NSColor) -> SCNCone {
            let geo = SCNCone(topRadius: 0,
                              bottomRadius: CGFloat(radius * 4.0),
                              height: CGFloat(pointerHeight))
            geo.firstMaterial?.diffuse.contents = color
            return geo
        }

        let xAxis = SCNNode(geometry: cylinder(color: .red))
        xAxis.position = SCNVector3(origin.x + CGFloat(length / 2.0), origin.y, origin.z)
        xAxis.rotation = SCNVector4(0, 0, 1, CGFloat(halfPi))

        let xPointer = SCNNode(geometry: cone(color: .red))
        xPointer.position = SCNVector3(origin.x + CGFloat(length + pointerOffset),
                                       origin.y,
                                       origin.z)
        xPointer.rotation = SCNVector4(0, 0, 1, CGFloat(halfPi))

        let yAxis = SCNNode(geometry: cylinder(color: .green))
        yAxis.position = SCNVector3(origin.x, origin.y + CGFloat(length / 2.0), origin.z)
        // Cylinders default to vertical; rotation kept for parity with ObjC.
        yAxis.rotation = SCNVector4(0, 1, 0, CGFloat(halfPi))

        let yPointer = SCNNode(geometry: cone(color: .green))
        yPointer.position = SCNVector3(origin.x,
                                       origin.y + CGFloat(length + pointerOffset),
                                       origin.z)
        yPointer.rotation = SCNVector4(1, 0, 0, CGFloat(pi))

        let zAxis = SCNNode(geometry: cylinder(color: .blue))
        zAxis.position = SCNVector3(origin.x, origin.y, origin.z + CGFloat(length / 2.0))
        zAxis.rotation = SCNVector4(1, 0, 0, CGFloat(halfPi))

        let zPointer = SCNNode(geometry: cone(color: .blue))
        zPointer.position = SCNVector3(origin.x,
                                       origin.y,
                                       origin.z + CGFloat(length + pointerOffset))
        zPointer.rotation = SCNVector4(1, 0, 0, CGFloat(-halfPi))

        parent.addChildNode(xAxis)
        parent.addChildNode(xPointer)
        parent.addChildNode(yAxis)
        parent.addChildNode(yPointer)
        parent.addChildNode(zAxis)
        parent.addChildNode(zPointer)
        return parent
    }

    /// Mirrors ObjC `+cubeOutlineWithInputLowerBound:inputUpperBound:radius:`
    /// (LUTPreviewScene.m:260-343). 12 cylinders (4 along X, 4 along Y, 4 along Z).
    private static func cubeOutline(inputLowerBound: Double,
                                     inputUpperBound: Double,
                                     radius: Double) -> SCNNode {
        let parent = SCNNode()
        let length = inputUpperBound - inputLowerBound
        let mid = inputLowerBound + length / 2.0

        let geometry = SCNCylinder(radius: CGFloat(radius / 2.0), height: CGFloat(length))
        geometry.firstMaterial?.diffuse.contents = NSColor.black

        func node(at position: SCNVector3, rotation: SCNVector4? = nil) -> SCNNode {
            let n = SCNNode(geometry: geometry)
            n.position = position
            if let rotation = rotation {
                n.rotation = rotation
            }
            return n
        }

        let xRotation = SCNVector4(0, 0, 1, CGFloat(Double.pi / 2.0))
        let zRotation = SCNVector4(1, 0, 0, CGFloat(Double.pi / 2.0))

        // X-axis edges (lying along X, rotated 90° around Z).
        parent.addChildNode(node(at: SCNVector3(mid, inputLowerBound, inputLowerBound), rotation: xRotation))
        parent.addChildNode(node(at: SCNVector3(mid, inputUpperBound, inputLowerBound), rotation: xRotation))
        parent.addChildNode(node(at: SCNVector3(mid, inputLowerBound, inputUpperBound), rotation: xRotation))
        parent.addChildNode(node(at: SCNVector3(mid, inputUpperBound, inputUpperBound), rotation: xRotation))

        // Y-axis edges (default cylinder orientation is along Y).
        parent.addChildNode(node(at: SCNVector3(inputLowerBound, mid, inputLowerBound)))
        parent.addChildNode(node(at: SCNVector3(inputUpperBound, mid, inputLowerBound)))
        parent.addChildNode(node(at: SCNVector3(inputLowerBound, mid, inputUpperBound)))
        parent.addChildNode(node(at: SCNVector3(inputUpperBound, mid, inputUpperBound)))

        // Z-axis edges (rotated 90° around X).
        parent.addChildNode(node(at: SCNVector3(inputLowerBound, inputLowerBound, mid), rotation: zRotation))
        parent.addChildNode(node(at: SCNVector3(inputUpperBound, inputLowerBound, mid), rotation: zRotation))
        parent.addChildNode(node(at: SCNVector3(inputLowerBound, inputUpperBound, mid), rotation: zRotation))
        parent.addChildNode(node(at: SCNVector3(inputUpperBound, inputUpperBound, mid), rotation: zRotation))

        return parent
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
