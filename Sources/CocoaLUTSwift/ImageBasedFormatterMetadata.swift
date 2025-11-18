import CoreGraphics
import Foundation

struct ImageBasedFormatterMetadata: Equatable, Sendable {
    var options: ImageBasedFormatterOptions
    var lutSize: Int?

    init(options: ImageBasedFormatterOptions, lutSize: Int? = nil) {
        self.options = options
        self.lutSize = lutSize
    }

    func passthroughDictionary(formatterID: String) -> [String: Any] {
        var payload: [String: Any] = [
            "fileTypeVariant": options.variant.rawValue,
            "bitDepth": options.bitDepth
        ]
        if let lutSize {
            payload["lutSize"] = lutSize
        }
        return [formatterID: payload]
    }

    static func fromPassthrough(_ options: [String: Any], formatterID: String) -> ImageBasedFormatterMetadata? {
        guard let formatterOptions = ImageBasedFormatterOptions.fromFormatterDictionary(options,
                                                                                       formatterID: formatterID) else {
            return nil
        }
        let lutSize: Int?
        if let formatterDictionary = options[formatterID] as? [String: Any] {
            lutSize = Self.extractInt(formatterDictionary["lutSize"])
        } else {
            lutSize = nil
        }
        return ImageBasedFormatterMetadata(options: formatterOptions, lutSize: lutSize)
    }

    static func from(image: CGImage,
                     preferredVariant: ImageBasedFormatterVariant = .tiff,
                     lutSize: Int? = nil) -> ImageBasedFormatterMetadata? {
        let depth = ImageBasedLUTUtilities.bitDepth(of: image)
        guard let options = ImageBasedFormatterOptions(variant: preferredVariant, bitDepth: depth) else {
            return nil
        }
        return ImageBasedFormatterMetadata(options: options, lutSize: lutSize)
    }

    func updating(lutSize newValue: Int?) -> ImageBasedFormatterMetadata {
        ImageBasedFormatterMetadata(options: options, lutSize: newValue)
    }

    private static func extractInt(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }
}

extension ImageBasedFormatterMetadata {
    static func passthroughDictionary(formatterID: String,
                                      variant: ImageBasedFormatterVariant,
                                      bitDepth: Int,
                                      lutSize: Int? = nil) -> [String: Any]? {
        guard let options = ImageBasedFormatterOptions(variant: variant, bitDepth: bitDepth) else {
            return nil
        }

        let metadata = ImageBasedFormatterMetadata(options: options, lutSize: lutSize)
        return metadata.passthroughDictionary(formatterID: formatterID)
    }
}
