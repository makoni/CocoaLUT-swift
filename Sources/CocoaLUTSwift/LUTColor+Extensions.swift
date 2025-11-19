#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public extension LUTColor {
    func luminanceRec709() -> Double {
        luminance(lumaR: 0.2126, lumaG: 0.7152, lumaB: 0.0722)
    }

    func luminance(lumaR: Double, lumaG: Double, lumaB: Double) -> Double {
        red * lumaR + green * lumaG + blue * lumaB
    }

    func inverted(minimumValue: Double, maximumValue: Double) -> LUTColor {
        let distance = abs(maximumValue - minimumValue)
        return LUTColor(red: distance - red, green: distance - green, blue: distance - blue)
    }

    func stringFormatted(withFloatingPointLength length: Int) -> String {
        let format = "%.\(length)f"
        return String(format: "\(format) \(format) \(format)", red, green, blue)
    }

    #if canImport(AppKit) || canImport(UIKit)
    var systemColor: SystemColor {
        #if canImport(AppKit)
        return SystemColor(deviceRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
        #else
        return SystemColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
        #endif
    }
    
    static func from(systemColor: SystemColor) -> LUTColor {
        #if canImport(AppKit)
        guard let converted = systemColor.usingColorSpace(NSColorSpace.deviceRGB) else { return .zeros() }
        return LUTColor(red: Double(converted.redComponent), green: Double(converted.greenComponent), blue: Double(converted.blueComponent))
        #elseif canImport(UIKit)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        systemColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return LUTColor(red: Double(r), green: Double(g), blue: Double(b))
        #endif
    }
    #endif
    
    static func + (lhs: LUTColor, rhs: LUTColor) -> LUTColor {
        LUTColor(red: lhs.red + rhs.red, green: lhs.green + rhs.green, blue: lhs.blue + rhs.blue)
    }
    
    static func - (lhs: LUTColor, rhs: LUTColor) -> LUTColor {
        LUTColor(red: lhs.red - rhs.red, green: lhs.green - rhs.green, blue: lhs.blue - rhs.blue)
    }
    
    static func * (lhs: LUTColor, rhs: Double) -> LUTColor {
        LUTColor(red: lhs.red * rhs, green: lhs.green * rhs, blue: lhs.blue * rhs)
    }
    
    func lerp(to other: LUTColor, amount: Double) -> LUTColor {
        lerping(to: other, amount: amount)
    }
}
