import Foundation
import simd

public struct LUTColorSpaceWhitePoint: Equatable, Sendable {
    public let whiteChromaticityX: Double
    public let whiteChromaticityY: Double
    public var name: String

    public init(whiteChromaticityX: Double, whiteChromaticityY: Double, name: String) {
        self.whiteChromaticityX = whiteChromaticityX
        self.whiteChromaticityY = whiteChromaticityY
        self.name = name
    }

    public var tristimulusValues: SIMD3<Double> {
        let capY = 1.0
        let capX = (capY / whiteChromaticityY) * whiteChromaticityX
        let capZ = (capY / whiteChromaticityY) * (1.0 - whiteChromaticityX - whiteChromaticityY)
        return SIMD3(capX, capY, capZ)
    }

    public func renamed(_ name: String) -> LUTColorSpaceWhitePoint {
        LUTColorSpaceWhitePoint(whiteChromaticityX: whiteChromaticityX,
                                 whiteChromaticityY: whiteChromaticityY,
                                 name: name)
    }
}

public extension LUTColorSpaceWhitePoint {
    static let d65 = LUTColorSpaceWhitePoint(whiteChromaticityX: 0.31271,
                                             whiteChromaticityY: 0.32902,
                                             name: "D65")

    static let d60 = LUTColorSpaceWhitePoint(whiteChromaticityX: 0.32168,
                                             whiteChromaticityY: 0.33767,
                                             name: "D60")

    static let d55 = LUTColorSpaceWhitePoint(whiteChromaticityX: 0.33242,
                                             whiteChromaticityY: 0.34743,
                                             name: "D55")

    static let d50 = LUTColorSpaceWhitePoint(whiteChromaticityX: 0.34567,
                                             whiteChromaticityY: 0.35850,
                                             name: "D50")

    static let dci = LUTColorSpaceWhitePoint(whiteChromaticityX: 0.314,
                                             whiteChromaticityY: 0.351,
                                             name: "DCI White")

    static let xyz = LUTColorSpaceWhitePoint(whiteChromaticityX: 1.0 / 3.0,
                                             whiteChromaticityY: 1.0 / 3.0,
                                             name: "XYZ White")

    static var knownWhitePoints: [LUTColorSpaceWhitePoint] {
        [d65, d60, d55, d50, dci, xyz]
    }

    static var knownColorTemperatureWhitePoints: [LUTColorSpaceWhitePoint] {
        [
            Self.fromColorTemperature(2900, customName: "Incandescent (2900K)"),
            Self.fromColorTemperature(3200, customName: "Tungsten (3200K)"),
            Self.fromColorTemperature(4400, customName: "Mixed (4400K)"),
            Self.fromColorTemperature(5600, customName: "Daylight (5600K)")
        ].compactMap { $0 }
    }

    static func fromColorTemperature(_ kelvin: Double) -> LUTColorSpaceWhitePoint? {
        guard kelvin >= 1667, kelvin <= 25000 else {
            return nil
        }

        let x: Double
        if kelvin <= 4000 {
            x = -0.2661239 * pow(10.0, 9.0) / pow(kelvin, 3.0)
                - 0.2343580 * pow(10.0, 6.0) / pow(kelvin, 2.0)
                + 0.8776956 * pow(10.0, 3.0) / kelvin
                + 0.179910
        } else {
            x = -3.0258469 * pow(10.0, 9.0) / pow(kelvin, 3.0)
                + 2.1070379 * pow(10.0, 6.0) / pow(kelvin, 2.0)
                + 0.2226347 * pow(10.0, 3.0) / kelvin
                + 0.240390
        }

        let y: Double
        if kelvin <= 2222 {
            y = -1.1063814 * pow(x, 3)
                - 1.34811020 * pow(x, 2)
                + 2.18555832 * x
                - 0.20219683
        } else if kelvin <= 4000 {
            y = -0.9549476 * pow(x, 3)
                - 1.37418593 * pow(x, 2)
                + 2.09137015 * x
                - 0.16748867
        } else {
            y = 3.0817580 * pow(x, 3)
                - 5.87338670 * pow(x, 2)
                + 3.75112997 * x
                - 0.37001483
        }

        let roundedName = "\(Int(kelvin))K"
        return LUTColorSpaceWhitePoint(whiteChromaticityX: x,
                                       whiteChromaticityY: y,
                                       name: roundedName)
    }

    static func fromColorTemperature(_ kelvin: Double, customName: String) -> LUTColorSpaceWhitePoint? {
        guard var point = fromColorTemperature(kelvin) else {
            return nil
        }
        point.name = customName
        return point
    }
}
