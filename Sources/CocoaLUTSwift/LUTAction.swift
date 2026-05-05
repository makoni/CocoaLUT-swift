import Foundation

public struct LUTActionMetadata: Sequence {
    private var entries: [(key: String, value: Any)]

    public init(entries: [(String, Any)] = []) {
        self.entries = []
        entries.forEach { appendOrUpdate(key: $0.0, value: $0.1) }
    }

    public func value(for key: String) -> Any? {
        entries.first { $0.key == key }?.value
    }

    public var orderedKeys: [String] {
        entries.map { $0.key }
    }

    public var dictionary: [String: Any] {
        entries.reduce(into: [:]) { result, element in
            result[element.key] = element.value
        }
    }

    public func makeIterator() -> IndexingIterator<[(key: String, value: Any)]> {
        entries.makeIterator()
    }

    internal func adding(key: String, value: Any) -> LUTActionMetadata {
        var copy = self
        copy.appendOrUpdate(key: key, value: value)
        return copy
    }

    private mutating func appendOrUpdate(key: String, value: Any) {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries[index].value = value
        } else {
            entries.append((key: key, value: value))
        }
    }
}

public final class LUTAction: NSObject, NSCopying {
    public typealias ActionBlock = (LUT) -> LUT
    public typealias ColorMatrix = (Double, Double, Double, Double, Double, Double, Double, Double, Double)

    public let actionBlock: ActionBlock
    public let actionName: String
    public let actionMetadata: LUTActionMetadata

    private var cachedInput: LUT?
    private var cachedOutput: LUT?

    public init(actionBlock: @escaping ActionBlock,
                actionName: String,
                actionMetadata: LUTActionMetadata) {
        precondition(!actionName.isEmpty, "Action name must not be empty")
        self.actionBlock = actionBlock
        self.actionName = actionName
        self.actionMetadata = actionMetadata
    }

    public static func action(with block: @escaping ActionBlock,
                              name: String,
                              metadataEntries: [(String, Any)]) -> LUTAction {
        LUTAction(actionBlock: block,
                  actionName: name,
                  actionMetadata: LUTActionMetadata(entries: metadataEntries))
    }

    public static func bypass(named name: String) -> LUTAction {
        action(with: { $0 },
               name: name,
               metadataEntries: [("id", "Bypass")])
    }

    public static func changeInputBounds(lower: Double,
                                         upper: Double,
                                         name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ChangeInputBounds"),
            ("inputLowerBound", lower),
            ("inputUpperBound", upper)
        ])
        return LUTAction(actionBlock: { $0.changingInputBounds(lower: lower, upper: upper) },
                         actionName: name ?? "Change Input Bounds",
                         actionMetadata: metadata)
    }

    public static func clamp(lower: Double,
                             upper: Double,
                             name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "Clamp"),
            ("lowerBound", lower),
            ("upperBound", upper)
        ])
        return LUTAction(actionBlock: { $0.clamped(lower: lower, upper: upper) },
                         actionName: name ?? "Clamp",
                         actionMetadata: metadata)
    }

    public static func resize(to size: Int,
                               name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "Resize"),
            ("size", size)
        ])
        return LUTAction(actionBlock: { $0.resized(to: size) },
                         actionName: name ?? "Resize",
                         actionMetadata: metadata)
    }

    public static func scaleToUnitRange(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleTo01")
        ])
        return LUTAction(actionBlock: { $0.scaledTo01() },
                         actionName: name ?? "Scale Absolute 0 to 1",
                         actionMetadata: metadata)
    }

    public static func scaleCurvesToUnitRange(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleCurvesTo01")
        ])
        return LUTAction(actionBlock: { $0.scaledCurvesTo01() },
                         actionName: name ?? "Scale Curves 0 to 1",
                         actionMetadata: metadata)
    }

    public static func scaleRGBToUnitRange(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleRGBTo01")
        ])
        return LUTAction(actionBlock: { $0.scaledRGBTo01() },
                         actionName: name ?? "Scale Absolute RGB 0 to 1",
                         actionMetadata: metadata)
    }

    public static func scaleCurvesRGBToUnitRange(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleCurvesRGBTo01")
        ])
        return LUTAction(actionBlock: { $0.scaledCurvesRGBTo01() },
                         actionName: name ?? "Scale Curves RGB 0 to 1",
                         actionMetadata: metadata)
    }

    public static func swizzle(method: LUT1D.SwizzleMethod,
                                strictness: Bool = false,
                                name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "MixCurves"),
            ("method", method.displayName),
            ("strictness", strictness ? "strict" : "relaxed")
        ])

        return LUTAction(actionBlock: { lut in
            lut.swizzling1DChannels(method: method, strictness: strictness) ?? lut
        },
        actionName: name ?? "Mix Curves (\(method.displayName))",
        actionMetadata: metadata)
    }

    public static func convertColorTemperature(sourceColorSpace: LUTColorSpace,
                                                sourceTransferFunction: LUTColorTransferFunction,
                                                sourceColorTemperature: LUTColorSpaceWhitePoint,
                                                destinationColorTemperature: LUTColorSpaceWhitePoint,
                                                name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ConvertColorTemperature"),
            ("sourceColorSpace", sourceColorSpace.name),
            ("sourceTransferFunction", sourceTransferFunction.name),
            ("sourceColorTemperature", sourceColorTemperature.name),
            ("destinationColorTemperature", destinationColorTemperature.name)
        ])

        return LUTAction(actionBlock: { lut in
            let sourceLUT = LUT3D(lattice: lut)
            guard let converted = try? LUTColorSpace.convertColorTemperature(sourceLUT,
                                                                             sourceColorSpace: sourceColorSpace,
                                                                             sourceTransferFunction: sourceTransferFunction,
                                                                             sourceColorTemperature: sourceColorTemperature,
                                                                             destinationColorTemperature: destinationColorTemperature) else {
                return lut
            }
            return converted.asLUT()
        },
        actionName: name ?? "Change Color Temperature",
        actionMetadata: metadata)
    }

    public static func scaleLegalToExtended(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleLegalToExtended")
        ])
        return LUTAction(actionBlock: { $0.scaledLegalToExtended() },
                         actionName: name ?? "Legal to Extended",
                         actionMetadata: metadata)
    }

    public static func scaleExtendedToLegal(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleExtendedToLegal")
        ])
        return LUTAction(actionBlock: { $0.scaledExtendedToLegal() },
                         actionName: name ?? "Extended to Legal",
                         actionMetadata: metadata)
    }

    public static func remapValues(inputLow: Double,
                                    inputHigh: Double,
                                    outputLow: Double,
                                    outputHigh: Double,
                                    name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleOutput"),
            ("inputLow", inputLow),
            ("inputHigh", inputHigh),
            ("outputLow", outputLow),
            ("outputHigh", outputHigh)
        ])
        return LUTAction(actionBlock: {
            $0.remappingValues(inputLow: inputLow,
                               inputHigh: inputHigh,
                               outputLow: outputLow,
                               outputHigh: outputHigh,
                               bounded: false)
        },
        actionName: name ?? "Scale Output",
        actionMetadata: metadata)
    }

    public static func remapValues(inputLowColor: LUTColor,
                                    inputHighColor: LUTColor,
                                    outputLowColor: LUTColor,
                                    outputHighColor: LUTColor,
                                    name: String? = nil) -> LUTAction {
        let entries: [(String, Any)] = [
            ("id", "ScaleOutputRGB"),
            ("inputLowColor", inputLowColor.rgbArray()),
            ("inputHighColor", inputHighColor.rgbArray()),
            ("outputLowColor", outputLowColor.rgbArray()),
            ("outputHighColor", outputHighColor.rgbArray())
        ]
        let metadata = LUTActionMetadata(entries: entries)
        return LUTAction(actionBlock: {
            $0.remappingValues(inputLowColor: inputLowColor,
                               inputHighColor: inputHighColor,
                               outputLowColor: outputLowColor,
                               outputHighColor: outputHighColor,
                               bounded: false)
        },
        actionName: name ?? "Scale Output RGB",
        actionMetadata: metadata)
    }

    public static func combine(with lut: LUT,
                               sourceDescription: String? = nil,
                               name: String? = nil) -> LUTAction {
        var entries: [(String, Any)] = [("id", "Combine")]
        if let sourceDescription {
            entries.append(("lutDescription", sourceDescription))
        }
        let metadata = LUTActionMetadata(entries: entries)
        return LUTAction(actionBlock: { $0.combined(with: lut) },
                         actionName: name ?? "Combine with LUT",
                         actionMetadata: metadata)
    }

    public static func combineBehind(lut: LUT,
                                     sourceDescription: String? = nil,
                                     name: String? = nil) -> LUTAction {
        var entries: [(String, Any)] = [("id", "CombineBehind")]
        if let sourceDescription {
            entries.append(("lutDescription", sourceDescription))
        }
        let metadata = LUTActionMetadata(entries: entries)
        return LUTAction(actionBlock: { lut.combined(with: $0) },
                         actionName: name ?? "Combine Behind LUT",
                         actionMetadata: metadata)
    }

    public static func applyColorMatrix(_ matrix: ColorMatrix,
                                        name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ApplyColorMatrix"),
            ("m00", matrix.0),
            ("m01", matrix.1),
            ("m02", matrix.2),
            ("m10", matrix.3),
            ("m11", matrix.4),
            ("m12", matrix.5),
            ("m20", matrix.6),
            ("m21", matrix.7),
            ("m22", matrix.8)
        ])
        return LUTAction(actionBlock: { $0.applyingColorMatrix(columnMajor: matrix) },
                         actionName: name ?? "Apply Color Matrix",
                         actionMetadata: metadata)
    }

    public static func offset(by color: LUTColor, name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "Offset"),
            ("redOffset", color.red),
            ("greenOffset", color.green),
            ("blueOffset", color.blue)
        ])
        return LUTAction(actionBlock: { $0.offsetting(by: color) },
                         actionName: name ?? "Offset",
                         actionMetadata: metadata)
    }

    public func apply(to lut: LUT) -> LUT {
        if let cachedInput,
           var cachedOutput,
           cachedInput.equals(lut) {
            cachedOutput.copyMetadata(from: lut)
            self.cachedOutput = cachedOutput
            return cachedOutput
        }

        var result = actionBlock(lut)
        result.copyMetadata(from: lut)
        cachedInput = lut
        cachedOutput = result
        return result
    }

    public func actionDetails() -> String {
        actionMetadata
            .filter { $0.key != "id" }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    public override var description: String {
        let details = actionDetails()
        return details.isEmpty ? actionName : "\(actionName): \(details)"
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = LUTAction(actionBlock: actionBlock,
                             actionName: actionName,
                             actionMetadata: actionMetadata)
        copy.cachedInput = cachedInput
        copy.cachedOutput = cachedOutput
        return copy
    }
}
