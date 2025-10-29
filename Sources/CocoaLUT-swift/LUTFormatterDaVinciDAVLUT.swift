import Foundation

enum LUTFormatterDaVinciDAVLUT {
    static let formatterIdentifier = "davinciDAVLUT"

    static func read(url: URL) throws -> LUT3D {
        try read(string: String(contentsOf: url, encoding: .utf8))
    }

    static func read(string: String) throws -> LUT3D {
        try LUTFormatterResolveDAT.read(string: string, variant: "DaVinci")
    }

    static func write(_ lut: LUT3D) throws -> String {
        try LUTFormatterResolveDAT.write(lut, options: .init(fileTypeVariant: "DaVinci"))
    }

    static func fileExtensions() -> [String] { ["davlut"] }

    static func formatterName() -> String { "DaVinci 3D LUT" }
}
