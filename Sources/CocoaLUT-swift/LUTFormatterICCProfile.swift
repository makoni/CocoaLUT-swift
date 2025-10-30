#if canImport(AppKit)
import AppKit

public enum LUTFormatterICCProfileError: Error, Equatable, LocalizedError {
    case invalidProfile
    case unsupportedComponentCount(Int)
    case colorConversionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidProfile:
            return "ICC profile could not be decoded."
        case .unsupportedComponentCount(let count):
            return "ICC profile must contain exactly three color components (found \(count))."
        case .colorConversionFailed:
            return "Unable to convert color samples using the supplied ICC profile."
        }
    }
}

public enum LUTFormatterICCProfile {
    public static let formatterIdentifier = "iccProfile"
    public static let uti = "com.apple.colorsync-profile"
    public static let fileExtensions = ["icc", "icm", "pf", "prof"]
    public static let defaultLUTSize = 33

    public static func read(url: URL, size: Int = defaultLUTSize) throws -> LUT3D {
        let data = try Data(contentsOf: url)
        return try read(data: data, size: size)
    }

    public static func read(data: Data, size: Int = defaultLUTSize) throws -> LUT3D {
        guard data.count >= 128 else {
            throw LUTFormatterICCProfileError.invalidProfile
        }
        let colorSpace = try colorSpace(from: data)
        let reference = LUT3D.identity(size: size, inputLowerBound: 0, inputUpperBound: 1)
        var result = reference

        try populate(&result, reference: reference, colorSpace: colorSpace)
        var finalized = result
        finalized.passthroughFileOptions[formatterIdentifier] = [:]
        return finalized
    }
}

private extension LUTFormatterICCProfile {
    static func colorSpace(from data: Data) throws -> NSColorSpace {
        guard let colorSpace = NSColorSpace(iccProfileData: data) else {
            throw LUTFormatterICCProfileError.invalidProfile
        }
        guard colorSpace.numberOfColorComponents == 3 else {
            throw LUTFormatterICCProfileError.unsupportedComponentCount(colorSpace.numberOfColorComponents)
        }
        return colorSpace
    }

    static func populate(_ lut: inout LUT3D,
                         reference: LUT3D,
                         colorSpace: NSColorSpace) throws {
        let size = lut.size
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let identity = reference.colorAt(r: r, g: g, b: b)
                    guard let transformed = convert(identity: identity, to: colorSpace) else {
                        throw LUTFormatterICCProfileError.colorConversionFailed
                    }
                    lut.setColor(transformed, r: r, g: g, b: b)
                }
            }
        }
    }

    static func convert(identity: LUTColor, to colorSpace: NSColorSpace) -> LUTColor? {
        let baseColor = NSColor(calibratedRed: CGFloat(identity.red),
                                green: CGFloat(identity.green),
                                blue: CGFloat(identity.blue),
                                alpha: 1)
        guard let converted = baseColor.usingColorSpace(colorSpace) else {
            return nil
        }

        var components = [CGFloat](repeating: 0, count: converted.numberOfComponents)
        components.withUnsafeMutableBufferPointer { buffer in
            if let pointer = buffer.baseAddress {
                converted.getComponents(pointer)
            }
        }

        guard components.count >= 3 else {
            return nil
        }

        return LUTColor.color(red: Double(components[0]),
                              green: Double(components[1]),
                              blue: Double(components[2]))
    }
}
#endif
