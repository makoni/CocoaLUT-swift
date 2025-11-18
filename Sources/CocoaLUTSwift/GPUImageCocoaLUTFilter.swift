import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

#if canImport(GPUImage)
import GPUImage

public final class GPUImageCocoaLUTFilter: GPUImageFilterGroup {
    public private(set) var lookupImage: CGImage
    private let lookupImageSource: GPUImagePicture

    public init(lut: LUT3D, bitDepth: Int = 8) throws {
        let cgImage = try LUTFormatterUnwrappedTexture.image(from: lut, options: .init(bitDepth: bitDepth))
        self.lookupImage = cgImage

#if canImport(UIKit)
        let platformImage = UIImage(cgImage: cgImage)
#elseif canImport(AppKit)
        let platformImage = NSImage(size: NSSize(width: cgImage.width, height: cgImage.height))
        platformImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
#else
        let platformImage = cgImage
#endif

        let lookupFilter = GPUImageLookupFilter()
        self.lookupImageSource = GPUImagePicture(image: platformImage)
        super.init()
        addFilter(lookupFilter)
        lookupImageSource.addTarget(lookupFilter, atTextureLocation: 1)
        lookupImageSource.processImage()
        self.initialFilters = [lookupFilter]
        self.terminalFilter = lookupFilter
    }

    public convenience init(lut: LUT, bitDepth: Int = 8) throws {
        try self.init(lut: LUT3D(lattice: lut), bitDepth: bitDepth)
    }
}

#else

public final class GPUImageCocoaLUTFilter {
    public let lut: LUT3D
    public let bitDepth: Int
    public let lookupImage: CGImage

    public init(lut: LUT3D, bitDepth: Int = 8) throws {
        self.lut = lut
        self.bitDepth = bitDepth
        self.lookupImage = try LUTFormatterUnwrappedTexture.image(from: lut, options: .init(bitDepth: bitDepth))
    }

    public convenience init(lut: LUT, bitDepth: Int = 8) throws {
        try self.init(lut: LUT3D(lattice: lut), bitDepth: bitDepth)
    }

    #if canImport(AppKit)
    public func makeLookupNSImage() -> NSImage {
        let image = NSImage(size: NSSize(width: lookupImage.width, height: lookupImage.height))
        image.addRepresentation(NSBitmapImageRep(cgImage: lookupImage))
        return image
    }
    #endif

    #if canImport(UIKit)
    public func makeLookupUIImage() -> UIImage {
        UIImage(cgImage: lookupImage)
    }
    #endif
}

#endif

public extension LUT3D {
    func gpuImageLookupFilter(bitDepth: Int = 8) throws -> GPUImageCocoaLUTFilter {
        try GPUImageCocoaLUTFilter(lut: self, bitDepth: bitDepth)
    }
}

public extension LUT {
    func gpuImageLookupFilter(bitDepth: Int = 8) throws -> GPUImageCocoaLUTFilter {
        try GPUImageCocoaLUTFilter(lut: self, bitDepth: bitDepth)
    }
}
