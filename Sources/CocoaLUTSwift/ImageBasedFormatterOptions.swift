import Foundation

public enum ImageBasedFormatterVariant: String, CaseIterable, Sendable {
    case tiff = "TIFF"

    public var supportedBitDepths: [Int] {
        switch self {
        case .tiff:
            return [8, 16]
        }
    }
}

public struct ImageBasedFormatterOptions: Equatable, Sendable {
    public var variant: ImageBasedFormatterVariant
    public var bitDepth: Int

    public init?(variant: ImageBasedFormatterVariant = .tiff, bitDepth: Int = 16) {
        guard variant.supportedBitDepths.contains(bitDepth) else { return nil }
        self.variant = variant
        self.bitDepth = bitDepth
    }

    public static var `default`: ImageBasedFormatterOptions {
        ImageBasedFormatterOptions(variant: .tiff, bitDepth: 16)!
    }

    public func formatterDictionary(formatterID: String) -> [String: Any] {
        [formatterID: [
            "fileTypeVariant": variant.rawValue,
            "bitDepth": bitDepth
        ]]
    }

    public static func fromFormatterDictionary(_ options: [String: Any],
                                               formatterID: String) -> ImageBasedFormatterOptions? {
        guard let formatterOptions = options[formatterID] as? [String: Any] else {
            return nil
        }

        let variantName = (formatterOptions["fileTypeVariant"] as? String) ?? ImageBasedFormatterVariant.tiff.rawValue
        let resolvedVariant: ImageBasedFormatterVariant
        if let directVariant = ImageBasedFormatterVariant(rawValue: variantName) {
            resolvedVariant = directVariant
        } else if let upperVariant = ImageBasedFormatterVariant(rawValue: variantName.uppercased()) {
            resolvedVariant = upperVariant
        } else {
            return nil
        }

        let depthValue: Int?
        if let value = formatterOptions["bitDepth"] as? Int {
            depthValue = value
        } else if let number = formatterOptions["bitDepth"] as? NSNumber {
            depthValue = number.intValue
        } else {
            depthValue = nil
        }

        guard let bitDepth = depthValue ?? resolvedVariant.supportedBitDepths.first else {
            return nil
        }

        return ImageBasedFormatterOptions(variant: resolvedVariant, bitDepth: bitDepth)
    }

    public static func validateFormatterDictionary(_ options: [String: Any],
                                                   formatterID: String) -> Bool {
        fromFormatterDictionary(options, formatterID: formatterID) != nil
    }
}
