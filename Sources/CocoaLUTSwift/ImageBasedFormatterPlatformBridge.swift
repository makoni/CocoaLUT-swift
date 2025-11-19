import CoreGraphics
import Foundation
import ImageIO

enum ImageBasedFormatterPlatformBridge {}

#if canImport(AppKit)
import AppKit

extension ImageBasedFormatterPlatformBridge {
    @MainActor
    static func nsImage(from cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    @MainActor
    static func cgImage(from nsImage: NSImage) -> CGImage? {
        if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        if let representation = nsImage.representations.compactMap({ ($0 as? NSBitmapImageRep)?.cgImage }).first {
            return representation
        }

        // Avoid logging "CGImageDestinationFinalize failed" for empty images
        guard !nsImage.representations.isEmpty else {
            return nil
        }

        guard let data = nsImage.tiffRepresentation else {
            return nil
        }

        if let imageRep = NSBitmapImageRep(data: data) {
            return imageRep.cgImage
        }

        return nil
    }
}
#endif

#if canImport(UIKit)
import UIKit
import CoreImage

extension ImageBasedFormatterPlatformBridge {
    static func uiImage(from cgImage: CGImage) -> UIImage {
        UIImage(cgImage: cgImage)
    }

    static func cgImage(from uiImage: UIImage) -> CGImage? {
        if let cgImage = uiImage.cgImage {
            return cgImage
        }
        if let ciImage = uiImage.ciImage {
            let context = CIContext(options: [.workingColorSpace: ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()])
            return context.createCGImage(ciImage, from: ciImage.extent)
        }
        return nil
    }
}
#endif
