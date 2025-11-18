import Foundation
import Dispatch

public enum LUTColorTransferFunctionType: Sendable {
    case sceneLinear
    case zeroToOne
    case any
}

public struct LUTColorTransferFunction: Sendable {
    private let transformedToLinearBlock: @Sendable (_ red: Double, _ green: Double, _ blue: Double) -> LUTColor
    private let linearToTransformedBlock: @Sendable (_ red: Double, _ green: Double, _ blue: Double) -> LUTColor

    public let name: String
    public let transferFunctionType: LUTColorTransferFunctionType

    public init(transformedToLinearBlock: @escaping @Sendable (_ red: Double, _ green: Double, _ blue: Double) -> LUTColor,
                linearToTransformedBlock: @escaping @Sendable (_ red: Double, _ green: Double, _ blue: Double) -> LUTColor,
                name: String,
                type: LUTColorTransferFunctionType) {
        self.transformedToLinearBlock = transformedToLinearBlock
        self.linearToTransformedBlock = linearToTransformedBlock
        self.name = name
        self.transferFunctionType = type
    }

    public func transformedToLinear(from color: LUTColor) -> LUTColor {
        transformedToLinearBlock(color.red, color.green, color.blue)
    }

    public func linearToTransformed(from color: LUTColor) -> LUTColor {
        linearToTransformedBlock(color.red, color.green, color.blue)
    }

    public func isCompatible(with other: LUTColorTransferFunction) -> Bool {
        transferFunctionType == other.transferFunctionType
        || transferFunctionType == .any
        || other.transferFunctionType == .any
    }
}

public extension LUTColorTransferFunction {
    static func withBlocks(transformedToLinear: @escaping @Sendable (_ red: Double, _ green: Double, _ blue: Double) -> LUTColor,
                            linearToTransformed: @escaping @Sendable (_ red: Double, _ green: Double, _ blue: Double) -> LUTColor,
                            name: String,
                            type: LUTColorTransferFunctionType) -> LUTColorTransferFunction {
        LUTColorTransferFunction(transformedToLinearBlock: transformedToLinear,
                                  linearToTransformedBlock: linearToTransformed,
                                  name: name,
                                  type: type)
    }

    static func with1DBlocks(transformedToLinear: @escaping @Sendable (Double) -> Double,
                              linearToTransformed: @escaping @Sendable (Double) -> Double,
                              name: String,
                              type: LUTColorTransferFunctionType) -> LUTColorTransferFunction {
        withBlocks(transformedToLinear: { r, g, b in
            LUTColor(red: transformedToLinear(r),
                     green: transformedToLinear(g),
                     blue: transformedToLinear(b))
        }, linearToTransformed: { r, g, b in
            LUTColor(red: linearToTransformed(r),
                     green: linearToTransformed(g),
                     blue: linearToTransformed(b))
        }, name: name, type: type)
    }

    static func knownColorTransferFunctions() -> [LUTColorTransferFunction] {
        [
            linearTransferFunction(),
            cineonTransferFunction(),
            jpLogTransferFunction(),
            redLogFilmTransferFunction(),
            gammaTransferFunction(gamma: 2.2),
            gammaTransferFunction(gamma: 2.4),
            gammaTransferFunction(gamma: 2.6),
            bt1886TransferFunction(),
            sRGBTransferFunction(),
            alexaLogCV3TransferFunction(ei: 800),
            sLogTransferFunction(),
            sLog2TransferFunction(),
            sLog3TransferFunction(),
            canonLogTransferFunction(),
            bmdFilmTransferFunction(),
            bmdFilm4KTransferFunction(),
            vLogTransferFunction()
        ]
    }

    static func linearTransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { $0 },
                      linearToTransformed: { $0 },
                      name: "Linear",
                      type: .any)
    }

    static func gammaTransferFunction(gamma: Double) -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            guard gamma != 1 else { return value }
            return pow(value, gamma)
        }, linearToTransformed: { value in
            guard gamma != 1 else { return value }
            return pow(value, 1.0 / gamma)
        }, name: "Gamma \(gamma)", type: .zeroToOne)
    }

    static func transformedLUT(from source: LUT3D,
                               sourceTransferFunction: LUTColorTransferFunction,
                               destinationTransferFunction: LUTColorTransferFunction) -> LUT3D {
        var transformed = LUT3D(size: source.size,
                                 inputLowerBound: source.inputLowerBound,
                                 inputUpperBound: source.inputUpperBound)
        transformed.title = source.title
        transformed.descriptionText = source.descriptionText
        transformed.metadata = source.metadata
        transformed.passthroughFileOptions = source.passthroughFileOptions

        source.loop { r, g, b in
            let sourceColor = source.colorAt(r: r, g: g, b: b)
            let intermediate = sourceTransferFunction.transformedToLinear(from: sourceColor)
            let destination = destinationTransferFunction.linearToTransformed(from: intermediate)
            transformed.setColor(destination, r: r, g: g, b: b)
        }

        return transformed
    }

    static func transformedLUT(from source: LUT1D,
                               sourceTransferFunction: LUTColorTransferFunction,
                               destinationTransferFunction: LUTColorTransferFunction) -> LUT1D {
        var result = source
        for index in 0..<source.size {
            let color = source.colorAt(index: index)
            let intermediate = sourceTransferFunction.transformedToLinear(from: color)
            let destination = destinationTransferFunction.linearToTransformed(from: intermediate)
            result.setColor(destination, index: index)
        }
        return result
    }

    static func transformedColor(from color: LUTColor,
                                 sourceTransferFunction: LUTColorTransferFunction,
                                 destinationTransferFunction: LUTColorTransferFunction) -> LUTColor {
        let intermediate = sourceTransferFunction.transformedToLinear(from: color)
        return destinationTransferFunction.linearToTransformed(from: intermediate)
    }
}

// MARK: - Private helper implementations

private extension LUTColorTransferFunction {
    static func bt1886TransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            if clamped <= 0.081 {
                return clamped / 4.5
            }
            return pow((clamped + 0.099) / 1.099, 2.2)
        }, linearToTransformed: { value in
            let output: Double
            if value <= 0.018 {
                output = 4.5 * value
            } else {
                output = 1.099 * pow(value, 1.0 / 2.2) - 0.099
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "BT.1886", type: .zeroToOne)
    }

    static func sRGBTransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clampLowerBound(value, lowerBound: 0)
            if clamped <= 0.04045 {
                return clamped / 12.92
            }
            return pow((clamped + 0.055) / 1.055, 2.4)
        }, linearToTransformed: { value in
            let clamped = LUTMath.clampLowerBound(value, lowerBound: 0)
            let output: Double
            if clamped <= 0.0031308 {
                output = 12.92 * clamped
            } else {
                output = 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "sRGB", type: .zeroToOne)
    }

    static func cineonTransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            return pow(10.0, (1023.0 * clamped - 685.0) / 300.0) - 0.0108 / (1.0 - 0.0108)
        }, linearToTransformed: { value in
            let output = (300.0 * log(value + 27.0 / 2473.0) + 685.0 * log(10.0)) / (1023.0 * log(10.0))
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "Cineon", type: .sceneLinear)
    }

    static func redLogFilmTransferFunction() -> LUTColorTransferFunction {
        cineonTransferFunction().renamed("REDLogFilm")
    }

    static func vLogTransferFunction() -> LUTColorTransferFunction {
        let cut1 = 0.01
        let cut2 = 0.181
        let b = 0.00873
        let c = 0.241514
        let d = 0.598206

        return with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            if clamped < cut2 {
                return (clamped - 0.125) / 5.6
            }
            return pow(10.0, (clamped - d) / c) - b
        }, linearToTransformed: { value in
            let output: Double
            if value < cut1 {
                output = 5.6 * value + 0.125
            } else {
                output = c * log10(value + b) + d
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "V-Log", type: .sceneLinear)
    }

    static func jpLogTransferFunction() -> LUTColorTransferFunction {
        let pdxLinReference = 0.18
        let pdxLogReference = 445.0
        let pdxNegativeGamma = 0.6
        let pdxDensityPerCodeValue = 0.002

        return with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            return pow(10.0, (clamped * 1023.0 - pdxLogReference) * pdxDensityPerCodeValue / pdxNegativeGamma) * pdxLinReference
        }, linearToTransformed: { value in
            let sanitized = max(value, 1e-10) / pdxLinReference
            let output = (pdxLogReference + log10(sanitized) * pdxNegativeGamma / pdxDensityPerCodeValue) / 1023.0
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "JPLog", type: .sceneLinear)
    }

    static func alexaLogCV3TransferFunction(ei: Double) -> LUTColorTransferFunction {
        let nominalEI = 400.0
        let blackSignal = 0.003907
        let midGraySignal = 0.01
        let encodingGain = 0.256598
        let encodingOffset = 0.391007

        let cut = 1.0 / 9.0
        let slope = 1.0 / (cut * log(10))
        let offset = log10(cut) - slope * cut
        let gain = ei / nominalEI
        let gray = midGraySignal / gain
        let encGain = (log(ei / nominalEI) / log(2.0) * (0.89 - 1.0) / 3.0 + 1.0) * encodingGain
        var encOffset = encodingOffset

        var nz = 0.0
        for _ in 0..<3 {
            nz = ((95.0 / 1023.0 - encOffset) / encGain - offset) / slope
            encOffset = encodingOffset - log10(1.0 + nz) * encGain
        }

        let aInitial = 1.0 / gray
        let bInitial = nz - blackSignal / gray
        let e = slope * aInitial * encGain
        let fInitial = encGain * (slope * bInitial + offset) + encOffset

        let s = 4.0 / (0.18 * ei)
        let t = blackSignal
        let bAdjusted = bInitial + aInitial * t
        let aAdjusted = aInitial * s
        let fAdjusted = fInitial + e * t
        let eAdjusted = e * s

        let cutAdjusted = (cut - bAdjusted) / aAdjusted
        let c = encGain
        let d = encOffset
        let finalA = aAdjusted
        let finalB = bAdjusted
        let finalF = fAdjusted
        let finalE = eAdjusted
        let finalCut = cutAdjusted

        return with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            if clamped > finalE * finalCut + finalF {
                return (pow(10.0, (clamped - d) / c) - finalB) / finalA
            }
            return (clamped - finalF) / finalE
        }, linearToTransformed: { value in
            let output: Double
            if value > finalCut {
                output = c * log10(finalA * value + finalB) + d
            } else {
                output = finalE * value + finalF
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "AlexaV3LogC EI \(Int(ei))", type: .sceneLinear)
    }

    static func canonLogTransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            let valueAsIRE = (clamped * 1023.0 - 64.0) / 876.0
            return (pow(10, (valueAsIRE - 0.0730597) / 0.529136) - 1) / 10.1596
        }, linearToTransformed: { value in
            let valueAsIRE = 0.529136 * log10(10.1596 * value + 1) + 0.0730597
            let output = (876.0 * valueAsIRE + 64.0) / 1023.0
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "CanonLog", type: .sceneLinear)
    }

    static func sLogTransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            if clamped >= 90.0 / 1023.0 {
                return (pow(10.0, ((clamped * 1023.0 - 64.0) / (940.0 - 64.0) - 0.616596 - 0.03) / 0.432699) - 0.037584) * 0.9
            }
            return ((clamped * 1023.0 - 64.0) / (940.0 - 64.0) - 0.030001222851889303) / 5.0 * 0.9
        }, linearToTransformed: { value in
            let output: Double
            if value >= 0.0000577055 {
                output = 0.160916 * log(51.1606 * value + 1.73054)
            } else {
                output = 0.0882513 + 4.75725 * value
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "S-Log", type: .sceneLinear)
    }

    static func sLog2TransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            let valueAsInt = 1023.0 * clamped
            if valueAsInt < 90.0 / 1023.0 {
                return ((valueAsInt - 64.0) / (940.0 - 64.0) - 0.030001222851889303) / 3.53881278538813 * 0.9
            }
            return (219.0 * (pow(10.0, ((valueAsInt - 64.0) / (940.0 - 64.0) - 0.616596 - 0.03) / 0.432699) - 0.037584) / 155.0) * 0.9
        }, linearToTransformed: { value in
            let output: Double
            if value < -0.0261851 {
                output = (3444.44 * value + 90.2811) / 1023.0
            } else {
                output = (164.617 * log(1.73054 + 36.2095 * value)) / 1023.0
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "S-Log2", type: .sceneLinear)
    }

    static func sLog3TransferFunction() -> LUTColorTransferFunction {
        with1DBlocks(transformedToLinear: { value in
            let clamped = LUTMath.clamp(value, lower: 0, upper: 1)
            if clamped >= 171.2102946929 / 1023.0 {
                return pow(10, ((clamped * 1023.0 - 420.0) / 261.5)) * (0.18 + 0.01) - 0.01
            }
            return (clamped * 1023.0 - 95.0) * 0.01125 / (171.2102946929 - 95.0)
        }, linearToTransformed: { value in
            let output: Double
            if value >= 0.01125 {
                output = (420.0 + log10((value + 0.01) / (0.18 + 0.01)) * 261.5) / 1023.0
            } else {
                output = (value * (171.2102946929 - 95.0) / 0.01125 + 95.0) / 1023.0
            }
            return LUTMath.clamp(output, lower: 0, upper: 1)
        }, name: "S-Log3", type: .sceneLinear)
    }

    static func bmdFilmTransferFunction() -> LUTColorTransferFunction {
        guard let bmdFilmToLinear = TransferFunctionLUTCache.shared.lut(named: "BMDFilm_to_Linear"),
              let linearToBmdFilm = TransferFunctionLUTCache.shared.lut(named: "Linear_to_BMDFilm") else {
            return linearTransferFunction()
        }

        return with1DBlocks(transformedToLinear: { value in
            let color = bmdFilmToLinear.color(at: LUTColor.uniform(value))
            return color.red
        }, linearToTransformed: { value in
            let color = linearToBmdFilm.color(at: LUTColor.uniform(value))
            return color.red
        }, name: "BMDFilm", type: .sceneLinear)
    }

    static func bmdFilm4KTransferFunction() -> LUTColorTransferFunction {
        guard let bmdFilm4KToLinear = TransferFunctionLUTCache.shared.lut(named: "BMDFilm4K_to_Linear"),
              let linearToBmdFilm4K = TransferFunctionLUTCache.shared.lut(named: "Linear_to_BMDFilm4K") else {
            return linearTransferFunction()
        }

        return with1DBlocks(transformedToLinear: { value in
            let color = bmdFilm4KToLinear.color(at: LUTColor.uniform(value))
            return color.red
        }, linearToTransformed: { value in
            let color = linearToBmdFilm4K.color(at: LUTColor.uniform(value))
            return color.red
        }, name: "BMDFilm4K", type: .sceneLinear)
    }

    func renamed(_ newName: String) -> LUTColorTransferFunction {
        LUTColorTransferFunction(transformedToLinearBlock: transformedToLinearBlock,
                                  linearToTransformedBlock: linearToTransformedBlock,
                                  name: newName,
                                  type: transferFunctionType)
    }
}

private final class TransferFunctionLUTCache: @unchecked Sendable {
    static let shared = TransferFunctionLUTCache()

    private var cache: [String: LUT1D] = [:]
    private let accessQueue = DispatchQueue(label: "com.cocoalut.transferFunctionCache", attributes: .concurrent)

    private init() {}

    func lut(named name: String) -> LUT1D? {
        accessQueue.sync { cache[name] } ?? load(named: name)
    }

    private func load(named name: String) -> LUT1D? {
        guard let url = Bundle.module.url(forResource: name,
                                          withExtension: "cube",
                                          subdirectory: "TransferFunctionLUTs") else {
            return nil
        }

        do {
            let result = try LUTCubeFormatter.read(url: url)
            guard let lut = result.lut1D else { return nil }
            accessQueue.async(flags: .barrier) {
                self.cache[name] = lut
            }
            return lut
        } catch {
            return nil
        }
    }
}
