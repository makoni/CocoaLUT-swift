import Foundation

#if canImport(CoreImage)
import CoreImage
#endif

// Compatibility shims for ObjC callers and older API names.
public extension LUT {
    /// ObjC-style initializer: attempt to parse a LUT from raw data using known formatters.
    /// Returns nil if no formatter could parse the data.
    init?(fromDataRepresentation data: Data) {
        // Try cube (text) first
        if let string = String(data: data, encoding: .utf8) {
            if let result = try? LUTCubeFormatter.read(string: string) {
                switch result {
                case .lut3D(let cube):
                    self = cube.asLUT()
                    return
                case .lut1D(let lut1d):
                    // Convert 1D to 3D lattice by filling using LUT1D
                    self = LUT3D(lattice: lut1d.toLUT3D(size: max(1, min(lut1d.size, LUTConstants.suggestedMax3DSize))).asLUT()).asLUT()
                    return
                }
            }
        }

        // Try common binary/image-based formatters that accept Data
        if let lut = try? LUTFormatterHaldCLUT.read(data: data) {
            self = lut.asLUT()
            return
        }

        if let lut = try? LUTFormatterUnwrappedTexture.read(data: data) {
            self = lut.asLUT()
            return
        }

        if let lut = try? LUTFormatterClipster.read(data: data) {
            self = lut.asLUT()
            return
        }

        if let lut = try? LUTFormatterFSIDAT.read(data: data) {
            self = lut.asLUT()
            return
        }

        if let lut = try? LUTFormatterArriLook.read(data: data) {
            self = lut.asLUT()
            return
        }

        // As a last resort, try parsing as an ICC profile LUT
        if let lut = try? LUTFormatterICCProfile.read(data: data) {
            self = lut.asLUT()
            return
        }

        return nil
    }

    /// ObjC-style property to obtain a canonical data representation (Cube text) where possible.
    var dataRepresentation: Data? {
        let payload = LUTCubeResult.lut3D(LUT3D(lattice: self))
        if let contents = try? LUTCubeFormatter.write(payload, options: LUTCubeOptions.default) {
            return contents.data(using: .utf8)
        }
        return nil
    }

    /// ObjC-style alias for `resized(to:)` used in older APIs.
    public func resizing(to newSize: Int) -> LUT {
        resized(to: newSize)
    }

    /// ObjC-style compatibility method for Core Image filter creation.
    #if canImport(CoreImage)
    func coreImageFilterWithCurrentColorSpace() throws -> CIFilter {
        try coreImageFilter(colorSpace: nil)
    }
    #endif
}

// Provide ObjC-friendly formatter wrapper types for callers expecting `LUTFormatterCube` and `LUTFormatterHaldCLUT`.
public final class LUTFormatterCube {
    private init() {}

    /// Read a LUT from text/buffer data. Tries to decode as a `.cube` text file first.
    public static func read(data: Data) throws -> LUT {
        if let string = String(data: data, encoding: .utf8) {
            let result = try LUTCubeFormatter.read(string: string)
            switch result {
            case .lut3D(let lut3d): return lut3d.asLUT()
            case .lut1D(let lut1d): return LUT3D(lattice: lut1d.toLUT3D(size: max(1, min(lut1d.size, LUTConstants.suggestedMax3DSize))).asLUT()).asLUT()
            }
        }
        throw LUTCubeFormatterError.invalidData
    }

    /// Write a LUT into cube-format data (utf8 string).
    public static func write(_ lut: LUT) throws -> Data {
        let payload = LUTCubeResult.lut3D(LUT3D(lattice: lut))
        let contents = try LUTCubeFormatter.write(payload, options: LUTCubeOptions.default)
        guard let d = contents.data(using: .utf8) else { throw LUTCubeFormatterError.invalidData }
        return d
    }
}

public enum LUTHaldCLUTCompat {
    public struct Options {
        public let bitDepth: Int
        public init(bitDepth: Int) { self.bitDepth = bitDepth }
    }

    public static func read(data: Data) throws -> LUT {
        let lut3d = try LUTFormatterHaldCLUT.read(data: data)
        return lut3d.asLUT()
    }

    public static func image(from lut: LUT, options: Options) throws -> (data: Data, uti: String) {
        let writeOptions = LUTFormatterHaldCLUT.Options(bitDepth: options.bitDepth)
        let image = try LUTFormatterHaldCLUT.image(from: LUT3D(lattice: lut), options: writeOptions)
        if writeOptions.bitDepth > 8 {
            let data = try ImageBasedLUTUtilities.tiffData(from: image)
            return (data, "public.tiff")
        } else {
            let data = try ImageBasedLUTUtilities.pngData(from: image)
            return (data, "public.png")
        }
    }
}
