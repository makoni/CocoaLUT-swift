#if canImport(CoreGraphics)
import CoreGraphics
import Testing
@testable import CocoaLUTSwift

@Suite final class ImageBasedFormatterMetadataTests {
    @Test func passthroughRoundTrip() throws {
        let options = try #require(ImageBasedFormatterOptions(variant: .tiff, bitDepth: 16))
        let metadata = ImageBasedFormatterMetadata(options: options, lutSize: 31)

        let dictionary = metadata.passthroughDictionary(formatterID: "cms")
        let roundTripped = try #require(ImageBasedFormatterMetadata.fromPassthrough(dictionary,
                                                                                    formatterID: "cms"))

        #expect(roundTripped.options == options)
        #expect(roundTripped.lutSize == 31)
    }

    @Test func metadataFromImageUsesImageBitDepth() throws {
        let image = try ImageBasedLUTUtilities.makeRGBImage(width: 1,
                                                            height: 1,
                                                            bitDepth: 8) { write in
            write(0, LUTColor.color(red: 0.2, green: 0.4, blue: 0.6))
        }

        let metadata = try #require(ImageBasedFormatterMetadata.from(image: image,
                                                                     preferredVariant: .tiff,
                                                                     lutSize: 11))

        #expect(metadata.options.variant == .tiff)
        #expect(metadata.options.bitDepth == 8)
        #expect(metadata.lutSize == 11)
    }

    @Test func passthroughBuilderValidatesInput() {
        let formatterID = "test"
        let dictionary = ImageBasedFormatterMetadata.passthroughDictionary(formatterID: formatterID,
                                                                           variant: .tiff,
                                                                           bitDepth: 16,
                                                                           lutSize: 25)

        let payload = dictionary?[formatterID] as? [String: Any]
        #expect(payload?["fileTypeVariant"] as? String == ImageBasedFormatterVariant.tiff.rawValue)
        #expect(payload?["bitDepth"] as? Int == 16)
        #expect(payload?["lutSize"] as? Int == 25)

        let invalid = ImageBasedFormatterMetadata.passthroughDictionary(formatterID: formatterID,
                                                                        variant: .tiff,
                                                                        bitDepth: 3,
                                                                        lutSize: nil)
        #expect(invalid == nil)
    }
}
#endif
