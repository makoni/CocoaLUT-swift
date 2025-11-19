import Foundation

#if canImport(CoreImage)
import CoreImage
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif


#if canImport(CoreImage)
public enum LUTImageRenderPath: Sendable {
    case coreImage
    case coreImageSoftware
    case direct
}

private enum LUTPlatformGlueError: Error {
    case failedToCreateFilter
}

extension LUT {
    public func coreImageFilter(colorSpace: CGColorSpace? = nil) throws -> CIFilter {
        let clampedSize = max(1, min(size, LUTConstants.maxCIColorCubeSize))
        let targetLUT: LUT
        if clampedSize == size {
            targetLUT = self
        } else {
            targetLUT = resized(to: clampedSize)
        }

        var working3D = LUT3D(lattice: targetLUT)
        let range = working3D.inputUpperBound - working3D.inputLowerBound
        if range != 1.0 && range < 2.0 {
            working3D = LUT3D(lattice: working3D.asLUT().changingInputBounds(lower: 0, upper: 1))
        }

        let cubeSize = working3D.size
        let entries = cubeSize * cubeSize * cubeSize * 4
        var cubeData = [Float](repeating: 0, count: entries)
        working3D.loop { r, g, b in
            let color = working3D.colorAt(r: r, g: g, b: b)
            let baseIndex = ((b * cubeSize * cubeSize) + (g * cubeSize) + r) * 4
            cubeData[baseIndex] = Float(color.red)
            cubeData[baseIndex + 1] = Float(color.green)
            cubeData[baseIndex + 2] = Float(color.blue)
            cubeData[baseIndex + 3] = 1.0
        }

        let data = cubeData.withUnsafeBufferPointer { Data(buffer: $0) }

        let filterName = colorSpace == nil ? "CIColorCube" : "CIColorCubeWithColorSpace"
        guard let filter = CIFilter(name: filterName) else {
            throw LUTPlatformGlueError.failedToCreateFilter
        }

        filter.setValue(NSNumber(value: cubeSize), forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")

        if let colorSpace {
            filter.setValue(colorSpace, forKey: "inputColorSpace")
        }

        return filter
    }

    public func process(ciImage: CIImage, colorSpace: CGColorSpace? = nil) -> CIImage? {
        let effectiveColorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let filter = try? coreImageFilter(colorSpace: effectiveColorSpace) else {
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        return filter.value(forKey: kCIOutputImageKey) as? CIImage
    }

    #if canImport(UIKit)
    public func process(uiImage: UIImage, colorSpace: CGColorSpace? = nil) -> UIImage? {
        let inputCIImage: CIImage
        if let existing = uiImage.ciImage {
            inputCIImage = existing
        } else if let converted = CIImage(image: uiImage) {
            inputCIImage = converted
        } else {
            return nil
        }

        guard let outputCIImage = process(ciImage: inputCIImage, colorSpace: colorSpace) else {
            return nil
        }

        return UIImage(ciImage: outputCIImage)
    }
    #endif

    #if canImport(AppKit)
    @MainActor
    public func process(nsImage: NSImage, renderPath: LUTImageRenderPath = .coreImage) -> NSImage? {
        switch renderPath {
        case .coreImage, .coreImageSoftware:
            let bitmapRep = Self.bitmapRepresentation(for: nsImage)
            let ciImage: CIImage
            let targetSize: NSSize

            if let bitmapRep {
                targetSize = NSSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)
                if let cgImage = bitmapRep.cgImage {
                    ciImage = CIImage(cgImage: cgImage)
                } else if let candidate = CIImage(bitmapImageRep: bitmapRep) {
                    ciImage = candidate
                } else {
                    return nil
                }
            } else if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                ciImage = CIImage(cgImage: cgImage)
                targetSize = NSSize(width: cgImage.width, height: cgImage.height)
            } else {
                return nil
            }

            guard let output = process(ciImage: ciImage) else { return nil }
            return NSImage.make(from: output,
                                targetSize: targetSize,
                                useSoftwareRenderer: renderPath == .coreImageSoftware)
        case .direct:
            return processNSImageDirectly(nsImage)
        }
    }

    @MainActor
    private func processNSImageDirectly(_ image: NSImage) -> NSImage? {
        guard let inputRep = Self.bitmapRepresentation(for: image) else {
            return nil
        }

        let width = inputRep.pixelsWide
        let height = inputRep.pixelsHigh
        guard let outputRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                               pixelsWide: width,
                                               pixelsHigh: height,
                                               bitsPerSample: 16,
                                               samplesPerPixel: 4,
                                               hasAlpha: true,
                                               isPlanar: false,
                                               colorSpaceName: .deviceRGB,
                                               bytesPerRow: 0,
                                               bitsPerPixel: 0) else {
            return nil
        }

        outputRep.size = NSSize(width: width, height: height)

        for x in 0..<width {
            for y in 0..<height {
                guard let rawColor = inputRep.colorAt(x: x, y: y),
                      let deviceColor = rawColor.usingColorSpace(NSColorSpace.deviceRGB) else {
                    continue
                }

                let lutColor = LUTColor.from(systemColor: deviceColor)
                let transformed = self.color(at: lutColor).clamped01()
                var outputColor = transformed.systemColor
                outputColor = outputColor.withAlphaComponent(deviceColor.alphaComponent)
                outputRep.setColor(outputColor, atX: x, y: y)
            }
        }

        let outputImage = NSImage(size: NSSize(width: width, height: height))
        outputImage.addRepresentation(outputRep)
        return outputImage
    }

    @MainActor
    private static func bitmapRepresentation(for image: NSImage) -> NSBitmapImageRep? {
        if let existing = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return existing
        }

        let pixelWidth = Int(round(image.size.width))
        let pixelHeight = Int(round(image.size.height))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        guard let fallback = NSBitmapImageRep(bitmapDataPlanes: nil,
                                              pixelsWide: pixelWidth,
                                              pixelsHigh: pixelHeight,
                                              bitsPerSample: 8,
                                              samplesPerPixel: 4,
                                              hasAlpha: true,
                                              isPlanar: false,
                                              colorSpaceName: NSColorSpaceName.deviceRGB,
                                              bytesPerRow: 0,
                                              bitsPerPixel: 0) else {
            return nil
        }

        let drawingRect = NSRect(origin: .zero, size: image.size)

        NSGraphicsContext.saveGraphicsState()
        if let bitmapContext = NSGraphicsContext(bitmapImageRep: fallback) {
            NSGraphicsContext.current = bitmapContext
            bitmapContext.cgContext.setBlendMode(.copy)
            image.draw(in: drawingRect,
                       from: drawingRect,
                       operation: .copy,
                       fraction: 1.0,
                       respectFlipped: false,
                       hints: nil)
            NSGraphicsContext.current = nil
        }
        NSGraphicsContext.restoreGraphicsState()

        return fallback
    }
    #endif
}

#endif

#if canImport(AppKit) && canImport(CoreImage)
private extension NSImage {
    @MainActor
    static func make(from ciImage: CIImage,
                     targetSize: NSSize,
                     useSoftwareRenderer: Bool) -> NSImage? {
        let resolvedExtent: CGRect
        if ciImage.extent.isInfinite {
            let width = Int(max(1, targetSize.width.rounded()))
            let height = Int(max(1, targetSize.height.rounded()))
            resolvedExtent = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        } else {
            resolvedExtent = ciImage.extent.integral
        }

        let width = Int(max(1, resolvedExtent.width.rounded()))
        let height = Int(max(1, resolvedExtent.height.rounded()))
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        let contextOptions: [CIContextOption: Any] = [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .useSoftwareRenderer: useSoftwareRenderer
        ]

        guard let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                               pixelsWide: width,
                                               pixelsHigh: height,
                                               bitsPerSample: 16,
                                               samplesPerPixel: 4,
                                               hasAlpha: true,
                                               isPlanar: false,
                                               colorSpaceName: NSColorSpaceName.deviceRGB,
                                               bytesPerRow: 0,
                                               bitsPerPixel: 0),
              let bitmapData = bitmapRep.bitmapData else {
            return nil
        }

        let ciContext = CIContext(options: contextOptions)
        let drawExtent = CGRect(origin: resolvedExtent.origin,
                                size: CGSize(width: width, height: height))

    ciContext.render(ciImage,
              toBitmap: bitmapData,
              rowBytes: bitmapRep.bytesPerRow,
              bounds: drawExtent,
              format: .RGBA16,
              colorSpace: colorSpace)

        let outputSize = NSSize(width: width, height: height)
        bitmapRep.size = outputSize

        let outputImage = NSImage(size: outputSize)
        outputImage.addRepresentation(bitmapRep)
        return outputImage
    }
}
#endif
