import Foundation
import simd

public struct LUTColorSpace: Equatable, Sendable {
    public struct Chromaticity: Equatable, Sendable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        var z: Double {
            1.0 - (x + y)
        }
    }

    private enum Definition: Equatable, Sendable {
        case primaries(whitePoint: LUTColorSpaceWhitePoint,
                        red: Chromaticity,
                        green: Chromaticity,
                        blue: Chromaticity)
        case forcedNPM(matrix: simd_double3x3)
    }

    public enum Error: Swift.Error, Equatable {
        case nonInvertibleMatrix
        case bradfordMatrixUnsupportedForForcedNPM
    }

    public let name: String
    public let forwardFootlambertCompensation: Double

    private let definition: Definition

    private init(definition: Definition,
                 forwardFootlambertCompensation: Double,
                 name: String) {
        self.definition = definition
        self.forwardFootlambertCompensation = forwardFootlambertCompensation
        self.name = name
    }

    public static func primaries(whitePoint: LUTColorSpaceWhitePoint,
                                  red: Chromaticity,
                                  green: Chromaticity,
                                  blue: Chromaticity,
                                  forwardFootlambertCompensation: Double = 1.0,
                                  name: String) -> LUTColorSpace {
        LUTColorSpace(definition: .primaries(whitePoint: whitePoint,
                                             red: red,
                                             green: green,
                                             blue: blue),
                      forwardFootlambertCompensation: forwardFootlambertCompensation,
                      name: name)
    }

    public static func forcedNPM(_ matrix: simd_double3x3,
                                  forwardFootlambertCompensation: Double = 1.0,
                                  name: String) -> LUTColorSpace {
        LUTColorSpace(definition: .forcedNPM(matrix: matrix),
                      forwardFootlambertCompensation: forwardFootlambertCompensation,
                      name: name)
    }

    public var defaultWhitePoint: LUTColorSpaceWhitePoint? {
        guard case let .primaries(whitePoint, _, _, _) = definition else {
            return nil
        }
        return whitePoint
    }

    public var redChromaticityX: Double? {
        guard case let .primaries(_, red, _, _) = definition else { return nil }
        return red.x
    }

    public var redChromaticityY: Double? {
        guard case let .primaries(_, red, _, _) = definition else { return nil }
        return red.y
    }

    public var greenChromaticityX: Double? {
        guard case let .primaries(_, _, green, _) = definition else { return nil }
        return green.x
    }

    public var greenChromaticityY: Double? {
        guard case let .primaries(_, _, green, _) = definition else { return nil }
        return green.y
    }

    public var blueChromaticityX: Double? {
        guard case let .primaries(_, _, _, blue) = definition else { return nil }
        return blue.x
    }

    public var blueChromaticityY: Double? {
        guard case let .primaries(_, _, _, blue) = definition else { return nil }
        return blue.y
    }

    public var forcesNPM: Bool {
        if case .forcedNPM = definition { return true }
        return false
    }

    public var forcedNPMMatrix: simd_double3x3? {
        if case let .forcedNPM(matrix) = definition { return matrix }
        return nil
    }
}

public extension LUTColorSpace {
    static func convert(_ lut: LUT3D,
                        from sourceColorSpace: LUTColorSpace,
                        sourceWhitePoint: LUTColorSpaceWhitePoint,
                        to destinationColorSpace: LUTColorSpace,
                        destinationWhitePoint: LUTColorSpaceWhitePoint,
                        useBradfordMatrix: Bool) throws -> LUT3D {
        if useBradfordMatrix, sourceColorSpace.forcesNPM || destinationColorSpace.forcesNPM {
            throw Error.bradfordMatrixUnsupportedForForcedNPM
        }

        let transformation = try transformationMatrix(from: sourceColorSpace,
                                                       sourceWhitePoint: sourceWhitePoint,
                                                       to: destinationColorSpace,
                                                       destinationWhitePoint: destinationWhitePoint,
                                                       useBradfordMatrix: useBradfordMatrix)

        var transformed = LUT3D(size: lut.size,
                                 inputLowerBound: lut.inputLowerBound,
                                 inputUpperBound: lut.inputUpperBound)
        transformed.title = lut.title
        transformed.descriptionText = lut.descriptionText
        transformed.metadata = lut.metadata
        transformed.passthroughFileOptions = lut.passthroughFileOptions

        let sourceFLCompensation = 1.0 / sourceColorSpace.forwardFootlambertCompensation
        let destinationFLCompensation = destinationColorSpace.forwardFootlambertCompensation
        let useFLCompensation = sourceFLCompensation != 1.0 / destinationFLCompensation

        lut.loop { r, g, b in
            var color = lut.colorAt(r: r, g: g, b: b)
            if useFLCompensation, sourceFLCompensation != 1.0 {
                color = color.multiplied(by: sourceFLCompensation)
            }

            let vector = SIMD3(color.red, color.green, color.blue)
            let transformedVector = transformation * vector
            var destinationColor = LUTColor(red: transformedVector.x,
                                            green: transformedVector.y,
                                            blue: transformedVector.z)

            if useFLCompensation, destinationFLCompensation != 1.0 {
                destinationColor = destinationColor.multiplied(by: destinationFLCompensation)
            }

            transformed.setColor(destinationColor, r: r, g: g, b: b)
        }

        return transformed
    }

    static func convertColorTemperature(_ lut: LUT3D,
                                        sourceColorSpace: LUTColorSpace,
                                        sourceTransferFunction: LUTColorTransferFunction,
                                        sourceColorTemperature: LUTColorSpaceWhitePoint,
                                        destinationColorTemperature: LUTColorSpaceWhitePoint) throws -> LUT3D {
        let linearTransfer = LUTColorTransferFunction.linearTransferFunction()
        let linearizedLUT = LUTColorTransferFunction.transformedLUT(from: lut,
                                                                    sourceTransferFunction: sourceTransferFunction,
                                                                    destinationTransferFunction: linearTransfer)
        let converted = try convert(linearizedLUT,
                                    from: sourceColorSpace,
                                    sourceWhitePoint: sourceColorTemperature,
                                    to: sourceColorSpace,
                                    destinationWhitePoint: destinationColorTemperature,
                                    useBradfordMatrix: false)
        return LUTColorTransferFunction.transformedLUT(from: converted,
                                                       sourceTransferFunction: linearTransfer,
                                                       destinationTransferFunction: sourceTransferFunction)
    }

    static func transformationMatrix(from sourceColorSpace: LUTColorSpace,
                                     sourceWhitePoint: LUTColorSpaceWhitePoint,
                                     to destinationColorSpace: LUTColorSpace,
                                     destinationWhitePoint: LUTColorSpaceWhitePoint,
                                     useBradfordMatrix: Bool) throws -> simd_double3x3 {
        let destinationInverse = try destinationColorSpace.npmInverse(using: destinationWhitePoint)
        let sourceNPM = try sourceColorSpace.npm(using: sourceWhitePoint)

        if useBradfordMatrix {
            let sourceCone = bradfordConeResponseMatrix * sourceWhitePoint.tristimulusValues
            let destinationCone = bradfordConeResponseMatrix * destinationWhitePoint.tristimulusValues
            let coneRatio = simd_double3x3(rows: [
                SIMD3(destinationCone.x / sourceCone.x, 0, 0),
                SIMD3(0, destinationCone.y / sourceCone.y, 0),
                SIMD3(0, 0, destinationCone.z / sourceCone.z)
            ])
            let bradfordMatrix = bradfordConeResponseMatrixInverse * coneRatio * bradfordConeResponseMatrix
            return destinationInverse * bradfordMatrix * sourceNPM
        } else {
            return destinationInverse * sourceNPM
        }
    }
}

public extension LUTColorSpace {
    var npm: simd_double3x3? {
        if let forced = forcedNPMMatrix {
            return forced
        }
        guard let whitePoint = defaultWhitePoint else {
            return nil
        }
        return try? npm(using: whitePoint)
    }

    func npm(using whitePoint: LUTColorSpaceWhitePoint) throws -> simd_double3x3 {
        if let forced = forcedNPMMatrix {
            return forced
        }

        guard case let .primaries(_, red, green, blue) = definition else {
            throw Error.nonInvertibleMatrix
        }

        let activeWhitePoint = whitePoint
        let whiteChromaticityZ = 1.0 - (activeWhitePoint.whiteChromaticityX + activeWhitePoint.whiteChromaticityY)

        let P = simd_double3x3(rows: [
            SIMD3(red.x, green.x, blue.x),
            SIMD3(red.y, green.y, blue.y),
            SIMD3(red.z, green.z, blue.z)
        ])

        let W = SIMD3(activeWhitePoint.whiteChromaticityX / activeWhitePoint.whiteChromaticityY,
                      1.0,
                      whiteChromaticityZ / activeWhitePoint.whiteChromaticityY)
        guard let inverseP = invert(P) else {
            throw Error.nonInvertibleMatrix
        }
        let pInverseDotW = inverseP * W

        let C = simd_double3x3(rows: [
            SIMD3(pInverseDotW.x, 0, 0),
            SIMD3(0, pInverseDotW.y, 0),
            SIMD3(0, 0, pInverseDotW.z)
        ])

        return P * C
    }

    func npmInverse(using whitePoint: LUTColorSpaceWhitePoint) throws -> simd_double3x3 {
        guard let inverse = invert(try npm(using: whitePoint)) else {
            throw Error.nonInvertibleMatrix
        }
        return inverse
    }

    func invert(_ matrix: simd_double3x3) -> simd_double3x3? {
        let determinant = simd_determinant(matrix)
        guard determinant.isFinite, abs(determinant) > Double.ulpOfOne else {
            return nil
        }
    return simd_inverse(matrix)
    }

    static var bradfordConeResponseMatrix: simd_double3x3 {
        simd_double3x3(rows: [
            SIMD3(0.8951, -0.7502, 0.0389),
            SIMD3(0.2664, 1.7135, -0.0685),
            SIMD3(-0.1614, 0.0367, 1.0296)
        ])
    }

    static var bradfordConeResponseMatrixInverse: simd_double3x3 {
        simd_double3x3(rows: [
            SIMD3(0.9869929, 0.4323053, -0.0085287),
            SIMD3(-0.1470543, 0.5183603, 0.0400428),
            SIMD3(0.1599627, 0.0492912, 0.9684867)
        ])
    }
}

public extension LUTColorSpace {
    static var knownColorSpaces: [LUTColorSpace] {
        [
            rec709,
            dciP3,
            rec2020,
            alexaWideGamut,
            sGamut3Cine,
            sGamut,
            bmcc,
            redColor,
            redColor2,
            redColor3,
            redColor4,
            dragonColor,
            dragonColor2,
            canonCinemaGamut,
            canonDCIP3Plus,
            vGamut,
            acesGamut,
            dciXYZ,
            xyz,
            adobeRGB,
            proPhotoRGB
        ]
    }

    static let rec709 = LUTColorSpace.primaries(whitePoint: .d65,
                                                 red: Chromaticity(x: 0.64, y: 0.33),
                                                 green: Chromaticity(x: 0.30, y: 0.60),
                                                 blue: Chromaticity(x: 0.15, y: 0.06),
                                                 name: "Rec. 709")

    static let canonDCIP3Plus = LUTColorSpace.primaries(whitePoint: .dci,
                                                         red: Chromaticity(x: 0.7400, y: 0.2700),
                                                         green: Chromaticity(x: 0.2200, y: 0.7800),
                                                         blue: Chromaticity(x: 0.0900, y: -0.0900),
                                                         name: "Canon DCI-P3+")

    static let canonCinemaGamut = LUTColorSpace.primaries(whitePoint: .d65,
                                                           red: Chromaticity(x: 0.7400, y: 0.2700),
                                                           green: Chromaticity(x: 0.1700, y: 1.1400),
                                                           blue: Chromaticity(x: 0.0800, y: -0.1000),
                                                           name: "Canon Cinema Gamut")

    static let bmcc = LUTColorSpace.primaries(whitePoint: .d65,
                                               red: Chromaticity(x: 0.901885370853, y: 0.249059467640),
                                               green: Chromaticity(x: 0.280038809783, y: 1.535129255560),
                                               blue: Chromaticity(x: 0.078873341398, y: -0.082629719848),
                                               name: "BMCC")

    static let redColor = LUTColorSpace.primaries(whitePoint: .d65,
                                                   red: Chromaticity(x: 0.682235759294, y: 0.320973856307),
                                                   green: Chromaticity(x: 0.295705729612, y: 0.613311106957),
                                                   blue: Chromaticity(x: 0.134524597085, y: 0.034410956920),
                                                   name: "REDcolor")

    static let redColor2 = LUTColorSpace.primaries(whitePoint: .d65,
                                                    red: Chromaticity(x: 0.858485322390, y: 0.316594954144),
                                                    green: Chromaticity(x: 0.292084791425, y: 0.667838655872),
                                                    blue: Chromaticity(x: 0.097651412967, y: -0.026565653796),
                                                    name: "REDcolor2")

    static let redColor3 = LUTColorSpace.primaries(whitePoint: .d65,
                                                    red: Chromaticity(x: 0.682450885401, y: 0.320302618634),
                                                    green: Chromaticity(x: 0.291813306036, y: 0.672642663443),
                                                    blue: Chromaticity(x: 0.109533374066, y: -0.006916855752),
                                                    name: "REDcolor3")

    static let redColor4 = LUTColorSpace.primaries(whitePoint: .d65,
                                                    red: Chromaticity(x: 0.682432347, y: 0.320314427),
                                                    green: Chromaticity(x: 0.291815909, y: 0.672638769),
                                                    blue: Chromaticity(x: 0.144290202, y: 0.050547336),
                                                    name: "REDcolor4")

    static let dragonColor = LUTColorSpace.primaries(whitePoint: .d65,
                                                      red: Chromaticity(x: 0.733696621349, y: 0.319213119879),
                                                      green: Chromaticity(x: 0.290807268864, y: 0.689667987865),
                                                      blue: Chromaticity(x: 0.083009416684, y: -0.050780628080),
                                                      name: "DRAGONcolor")

    static let dragonColor2 = LUTColorSpace.primaries(whitePoint: .d65,
                                                       red: Chromaticity(x: 0.733671536367, y: 0.319227712042),
                                                       green: Chromaticity(x: 0.290804815281, y: 0.689668775507),
                                                       blue: Chromaticity(x: 0.143989704285, y: 0.050047743857),
                                                       name: "DRAGONcolor2")

    static let proPhotoRGB = LUTColorSpace.primaries(whitePoint: .d65,
                                                      red: Chromaticity(x: 0.7347, y: 0.2653),
                                                      green: Chromaticity(x: 0.1596, y: 0.8404),
                                                      blue: Chromaticity(x: 0.0366, y: 0.0001),
                                                      name: "ProPhoto RGB")

    static let adobeRGB = LUTColorSpace.primaries(whitePoint: .d65,
                                                   red: Chromaticity(x: 0.64, y: 0.33),
                                                   green: Chromaticity(x: 0.21, y: 0.71),
                                                   blue: Chromaticity(x: 0.15, y: 0.06),
                                                   name: "Adobe RGB")

    static let dciP3 = LUTColorSpace.primaries(whitePoint: .dci,
                                                red: Chromaticity(x: 0.680, y: 0.320),
                                                green: Chromaticity(x: 0.265, y: 0.69),
                                                blue: Chromaticity(x: 0.15, y: 0.06),
                                                name: "DCI-P3")

    static let rec2020 = LUTColorSpace.primaries(whitePoint: .d65,
                                                  red: Chromaticity(x: 0.708, y: 0.292),
                                                  green: Chromaticity(x: 0.170, y: 0.797),
                                                  blue: Chromaticity(x: 0.131, y: 0.046),
                                                  name: "Rec. 2020")

    static let alexaWideGamut = LUTColorSpace.primaries(whitePoint: .d65,
                                                         red: Chromaticity(x: 0.6840, y: 0.3130),
                                                         green: Chromaticity(x: 0.2210, y: 0.8480),
                                                         blue: Chromaticity(x: 0.0861, y: -0.1020),
                                                         name: "Alexa Wide Gamut")

    static let sGamut3Cine = LUTColorSpace.primaries(whitePoint: .d65,
                                                      red: Chromaticity(x: 0.76600, y: 0.27500),
                                                      green: Chromaticity(x: 0.22500, y: 0.80000),
                                                      blue: Chromaticity(x: 0.08900, y: -0.08700),
                                                      name: "S-Gamut3.Cine")

    static let sGamut = LUTColorSpace.primaries(whitePoint: .d65,
                                                 red: Chromaticity(x: 0.73000, y: 0.28000),
                                                 green: Chromaticity(x: 0.14000, y: 0.85500),
                                                 blue: Chromaticity(x: 0.10000, y: -0.05000),
                                                 name: "S-Gamut/S-Gamut3")

    static let vGamut = LUTColorSpace.primaries(whitePoint: .d65,
                                                 red: Chromaticity(x: 0.730, y: 0.280),
                                                 green: Chromaticity(x: 0.165, y: 0.840),
                                                 blue: Chromaticity(x: 0.100, y: -0.030),
                                                 name: "V-Gamut")

    static let acesGamut = LUTColorSpace.primaries(whitePoint: .d60,
                                                    red: Chromaticity(x: 0.73470, y: 0.26530),
                                                    green: Chromaticity(x: 0.00000, y: 1.00000),
                                                    blue: Chromaticity(x: 0.00010, y: -0.07700),
                                                    name: "ACES Gamut")

    static let dciXYZ = LUTColorSpace.forcedNPM(
        simd_double3x3(rows: [
            SIMD3(1.0, 0.0, 0.0),
            SIMD3(0.0, 1.0, 0.0),
            SIMD3(0.0, 0.0, 1.0)
        ]),
        forwardFootlambertCompensation: 0.916555,
        name: "DCI-XYZ"
    )

    static let xyz = LUTColorSpace.primaries(whitePoint: .xyz,
                                              red: Chromaticity(x: 1, y: 0),
                                              green: Chromaticity(x: 0, y: 1),
                                              blue: Chromaticity(x: 0, y: 0),
                                              forwardFootlambertCompensation: 0.916555,
                                              name: "CIE-XYZ")
}
