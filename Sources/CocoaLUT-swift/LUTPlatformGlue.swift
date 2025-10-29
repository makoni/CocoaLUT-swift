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
#if DEBUG
                if let sample = bitmapRep.colorAt(x: 0, y: 0)?.usingColorSpace(NSColorSpace.genericRGB) {
                    print("DEBUG Bitmap sample R=\(sample.redComponent) G=\(sample.greenComponent) B=\(sample.blueComponent)")
                }
                if let space = ciImage.colorSpace {
                    print("DEBUG CIImage color space: \(space)")
                } else {
                    print("DEBUG CIImage color space: nil")
                }
#endif
            } else if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
#if DEBUG
                print("DEBUG Falling back to CGImage-based CIImage; representations: \(nsImage.representations.map { String(describing: type(of: $0)) })")
#endif
                ciImage = CIImage(cgImage: cgImage)
                targetSize = NSSize(width: cgImage.width, height: cgImage.height)
            } else {
                return nil
            }

            let outputColorSpace = ciImage.colorSpace
            guard let output = process(ciImage: ciImage, colorSpace: outputColorSpace) else { return nil }
#if DEBUG
            var debugOptions: [CIContextOption: Any] = [.useSoftwareRenderer: true]
            if let space = outputColorSpace {
                debugOptions[.workingColorSpace] = space
                debugOptions[.outputColorSpace] = space
            }
            let debugContext = CIContext(options: debugOptions)
            if let inputCG = debugContext.createCGImage(ciImage, from: ciImage.extent) {
                let inputRep = NSBitmapImageRep(cgImage: inputCG)
                if let sample = inputRep.colorAt(x: 0, y: 0) {
                    print("DEBUG Input sample R=\(sample.redComponent) G=\(sample.greenComponent) B=\(sample.blueComponent)")
                }
            }
            if let outputCG = debugContext.createCGImage(output, from: output.extent) {
                let outputRep = NSBitmapImageRep(cgImage: outputCG)
                if let sample = outputRep.colorAt(x: 0, y: 0) {
                    print("DEBUG Output sample R=\(sample.redComponent) G=\(sample.greenComponent) B=\(sample.blueComponent)")
                }
            }
#endif
            return NSImage.make(from: output,
                                targetSize: targetSize,
                                useSoftwareRenderer: renderPath == .coreImageSoftware)
        case .direct:
            return processNSImageDirectly(nsImage)
        }
    }

    private func processNSImageDirectly(_ image: NSImage) -> NSImage? {
        guard let inputRep = Self.bitmapRepresentation(for: image) else {
            return nil
        }

        let width = inputRep.pixelsWide
        let height = inputRep.pixelsHigh
        guard let outputRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                               pixelsWide: width,
                                               pixelsHigh: height,
                                               bitsPerSample: inputRep.bitsPerSample,
                                               samplesPerPixel: inputRep.samplesPerPixel,
                                               hasAlpha: inputRep.hasAlpha,
                                               isPlanar: false,
                                               colorSpaceName: NSColorSpaceName.calibratedRGB,
                                               bytesPerRow: 0,
                                               bitsPerPixel: 0) else {
            return nil
        }

        for x in 0..<width {
            for y in 0..<height {
                guard let systemColor = inputRep.colorAt(x: x, y: y)?.usingColorSpace(NSColorSpace.genericRGB) else { continue }
                let lutColor = LUTColor.color(red: Double(systemColor.redComponent),
                                              green: Double(systemColor.greenComponent),
                                              blue: Double(systemColor.blueComponent))
                let transformed = self.color(at: lutColor).clamped01()
                let outputColor = NSColor(calibratedRed: CGFloat(transformed.red),
                                          green: CGFloat(transformed.green),
                                          blue: CGFloat(transformed.blue),
                                          alpha: systemColor.alphaComponent)
                outputRep.setColor(outputColor, atX: x, y: y)
            }
        }

        let outputImage = NSImage(size: NSSize(width: width, height: height))
        outputImage.addRepresentation(outputRep)
        return outputImage
    }

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
                                              colorSpaceName: NSColorSpaceName.calibratedRGB,
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

#if DEBUG
        if let sample = fallback.colorAt(x: 0, y: 0)?.usingColorSpace(NSColorSpace.genericRGB) {
            print("DEBUG Fallback bitmap sample R=\(sample.redComponent) G=\(sample.greenComponent) B=\(sample.blueComponent)")
        }
#endif

        return fallback
    }
    #endif
}

#endif

#if canImport(AppKit) && canImport(CoreImage)
private extension NSImage {
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
#if DEBUG
        print("DEBUG Output representations: \(outputImage.representations.map { String(describing: type(of: $0)) })")
#endif
        return outputImage
    }
}
#endif
