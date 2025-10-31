import Foundation

public enum LUTFormatterOutputType: String, Sendable {
    case lut1D
    case lut3D
    case either
}

public enum LUTFormatterPayload {
    case lut1D(LUT1D)
    case lut3D(LUT3D)

    public var outputType: LUTFormatterOutputType {
        switch self {
        case .lut1D:
            return .lut1D
        case .lut3D:
            return .lut3D
        }
    }

    public var passthroughFileOptions: [String: Any] {
        switch self {
        case .lut1D(let lut):
            return lut.passthroughFileOptions
        case .lut3D(let lut):
            return lut.passthroughFileOptions
        }
    }
}

public struct LUTFormatterDescriptor {
    public struct Roles: OptionSet, Sendable {
        public let rawValue: Int

        public static let read = Roles(rawValue: 1 << 0)
        public static let write = Roles(rawValue: 1 << 1)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public let id: String
    public let name: String
    public let fileExtensions: [String]
    public let output: LUTFormatterOutputType
    public let roles: Roles
    public let uti: String?
    public let defaultOptions: [String: Any]?
    public let allOptions: [[String: Any]]?
    public let alternateIdentifiers: [String]

    private let reader: ((URL) throws -> LUTFormatterPayload)?
    private let writer: ((LUTFormatterPayload, URL, [String: Any]?) throws -> Void)?

    public init(id: String,
                name: String,
                fileExtensions: [String],
                output: LUTFormatterOutputType,
                roles: Roles,
                uti: String? = nil,
                defaultOptions: [String: Any]? = nil,
                allOptions: [[String: Any]]? = nil,
                alternateIdentifiers: [String] = [],
                reader: ((URL) throws -> LUTFormatterPayload)? = nil,
                writer: ((LUTFormatterPayload, URL, [String: Any]?) throws -> Void)? = nil) {
        self.id = id
        self.name = name
        self.fileExtensions = fileExtensions
        self.output = output
        self.roles = roles
        self.uti = uti
        self.defaultOptions = defaultOptions
        self.allOptions = allOptions
        self.alternateIdentifiers = alternateIdentifiers
        self.reader = reader
        self.writer = writer
    }

    public func read(url: URL) throws -> LUTFormatterPayload {
        guard roles.contains(.read), let reader else {
            throw CocoaLUT.Error.readUnsupportedFormatter(id)
        }
        return try reader(url)
    }

    public func write(_ payload: LUTFormatterPayload,
                      to url: URL,
                      options: [String: Any]? = nil) throws {
        guard roles.contains(.write), let writer else {
            throw CocoaLUT.Error.writeUnsupportedFormatter(id)
        }
        try writer(payload, url, options)
    }
}

private enum LUTFormatterRegistry {
    static func descriptors() -> [LUTFormatterDescriptor] {
    [cubeDescriptor(),
     threeDLDescriptor(),
     haldDescriptor(),
     ilutDescriptor(),
     olutDescriptor(),
     quantelDescriptor(),
     fsiDATDescriptor(),
     clipsterDescriptor(),
     discreetDescriptor(),
     cmsDescriptor(),
     nucodaDescriptor(),
     resolveDATDescriptor(),
     davinciDescriptor(),
     matchLightDescriptor(),
     arriLookDescriptor(),
     unwrappedTextureDescriptor()]
    }

    private static func legacyIdentifier(for canonicalID: String) -> String {
        "com.cocoalut.formatter.\(canonicalID.lowercased())"
    }

    private static func mirroredDefaultOptions(for canonicalID: String,
                                                options: [String: Any]) -> [String: Any] {
        var updated = options
        let legacyID = legacyIdentifier(for: canonicalID)
        if let canonicalValue = updated[canonicalID], updated[legacyID] == nil {
            updated[legacyID] = canonicalValue
        } else if let legacyValue = updated[legacyID], updated[canonicalID] == nil {
            updated[canonicalID] = legacyValue
        }
        return updated
    }

    private static func payloadByAddingLegacyAlias(_ payload: LUTFormatterPayload,
                                                   canonicalID: String) -> LUTFormatterPayload {
        let legacyID = legacyIdentifier(for: canonicalID)

        func mirroredOptions(_ options: [String: Any]) -> [String: Any] {
            if let canonicalOptions = options[canonicalID] {
                var updated = options
                if updated[legacyID] == nil {
                    updated[legacyID] = canonicalOptions
                }
                return updated
            }

            if let legacyOptions = options[legacyID] {
                var updated = options
                if updated[canonicalID] == nil {
                    updated[canonicalID] = legacyOptions
                }
                return updated
            }

            return options
        }

        switch payload {
        case .lut1D(var lut):
            lut.passthroughFileOptions = mirroredOptions(lut.passthroughFileOptions)
            return .lut1D(lut)
        case .lut3D(var lut):
            lut.passthroughFileOptions = mirroredOptions(lut.passthroughFileOptions)
            return .lut3D(lut)
        }
    }

    static func descriptor(for identifier: String) -> LUTFormatterDescriptor? {
        descriptors().first { descriptor in
            descriptor.id == identifier || descriptor.alternateIdentifiers.contains(identifier)
        }
    }

    static func descriptors(forFileExtension ext: String) -> [LUTFormatterDescriptor] {
        let lowercasedExtension = ext.lowercased()
        return descriptors().filter { descriptor in
            descriptor.fileExtensions.contains { $0.lowercased() == lowercasedExtension }
        }
    }

    private static func cubeDescriptor() -> LUTFormatterDescriptor {
        let variants: [[String: Any]] = [
            ["fileTypeVariant": LUTCubeVariant.resolve.rawValue],
            ["fileTypeVariant": LUTCubeVariant.resolveLegacy.rawValue],
            ["fileTypeVariant": LUTCubeVariant.iridasAdobe.rawValue],
            ["fileTypeVariant": LUTCubeVariant.highPrecision.rawValue]
        ]
        let defaultVariant = LUTCubeVariant.resolve.rawValue
        let cubeKey = LUTCubeFormatter.formatterIdentifier
        let legacyKey = LUTCubeFormatter.legacyFormatterIdentifier
        let defaultOptions: [String: Any] = [
            cubeKey: ["fileTypeVariant": defaultVariant],
            legacyKey: ["fileTypeVariant": defaultVariant]
        ]

        return LUTFormatterDescriptor(
            id: cubeKey,
            name: "Cube LUT",
            fileExtensions: ["cube"],
            output: .either,
            roles: [.read, .write],
            uti: "com.blackmagicdesign.cube",
            defaultOptions: defaultOptions,
            allOptions: variants,
            alternateIdentifiers: [legacyKey, "com.blackmagicdesign.cube"],
            reader: { url in
                let result = try LUTCubeFormatter.read(url: url)
                return normalizeCubePayload(result)
            },
            writer: { payload, url, options in
                let result: LUTCubeResult
                switch payload {
                case .lut1D(let lut):
                    result = .lut1D(lut)
                case .lut3D(let lut):
                    result = .lut3D(lut)
                }

                let cubeOptions = normalizedCubeOptions(from: options)
                let contents = try LUTCubeFormatter.write(result, options: cubeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func threeDLDescriptor() -> LUTFormatterDescriptor {
        let formatterKey = LUTFormatter3DL.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterKey: [
                "fileTypeVariant": LUTFormatter3DL.Variant.nuke.rawValue,
                "integerMaxOutput": LUTMath.maxInteger(bitDepth: 16),
                "lutSize": 32
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterKey, options: defaultOptions)

        let allOptions: [[String: Any]] = [
            [
                "fileTypeVariant": LUTFormatter3DL.Variant.lustre.rawValue,
                "integerMaxOutput": [
                    LUTMath.maxInteger(bitDepth: 12),
                    LUTMath.maxInteger(bitDepth: 16)
                ],
                "lutSize": [17, 33, 65]
            ],
            [
                "fileTypeVariant": LUTFormatter3DL.Variant.nuke.rawValue,
                "integerMaxOutput": [
                    LUTMath.maxInteger(bitDepth: 12),
                    LUTMath.maxInteger(bitDepth: 16)
                ],
                "lutSize": [32, 64]
            ],
            [
                "fileTypeVariant": LUTFormatter3DL.Variant.legacy.rawValue,
                "integerMaxOutput": [LUTMath.maxInteger(bitDepth: 12)],
                "lutSize": [17]
            ]
        ]

        return LUTFormatterDescriptor(
            id: formatterKey,
            name: "Autodesk 3D LUT",
            fileExtensions: ["3dl"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "com.autodesk.3dl",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["com.autodesk.3dl"],
            reader: { url in
                let lut = try LUTFormatter3DL.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterKey)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }
                let writeOptions = normalized3DLOptions(from: options)
                let contents = try LUTFormatter3DL.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func haldDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterHaldCLUT.formatterIdentifier
        let defaultMetadata = ImageBasedFormatterMetadata(
            options: ImageBasedFormatterOptions(variant: .tiff, bitDepth: 16)!,
            lutSize: 36
        )

    let defaultOptions = defaultMetadata.passthroughDictionary(formatterID: formatterID)
    let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)
        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": ImageBasedFormatterVariant.tiff.rawValue,
            "bitDepth": ImageBasedFormatterVariant.tiff.supportedBitDepths,
            "lutSize": [9, 16, 25, 36, 49, 64]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Hald CLUT",
            fileExtensions: ["tiff", "tif"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.image",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: [formatterID.lowercased()],
            reader: { url in
                let data = try Data(contentsOf: url)
                let lut = try LUTFormatterHaldCLUT.read(data: data)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedHaldOptions(from: options) ?? LUTFormatterHaldCLUT.Options(bitDepth: 16)
                let image = try LUTFormatterHaldCLUT.image(from: lut, options: writeOptions)

                let data: Data
                switch url.pathExtension.lowercased() {
                case "png":
                    data = try ImageBasedLUTUtilities.pngData(from: image)
                default:
                    data = try ImageBasedLUTUtilities.tiffData(from: image)
                }

                try data.write(to: url, options: .atomic)
            }
        )
    }

    private static func ilutDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterILUT.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "ILUT",
                "lutSize": 16384
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "ILUT",
            "lutSize": [16384]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Blackmagic Design 1D LUT",
            fileExtensions: ["ilut"],
            output: .lut1D,
            roles: [.read, .write],
            uti: "com.blackmagicdesign.ilut",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["com.blackmagicdesign.ilut"],
            reader: { url in
                let lut = try LUTFormatterILUT.read(url: url)
                return payloadByAddingLegacyAlias(.lut1D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, _ in
                guard case .lut1D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut1D, actual: payload.outputType)
                }
                let contents = try LUTFormatterILUT.write(lut)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func olutDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterOLUT.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "OLUT",
                "lutSize": 4096
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "OLUT",
            "lutSize": [4096]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Blackmagic Design 1D LUT",
            fileExtensions: ["olut"],
            output: .lut1D,
            roles: [.read, .write],
            uti: "com.blackmagicdesign.olut",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["com.blackmagicdesign.olut"],
            reader: { url in
                let lut = try LUTFormatterOLUT.read(url: url)
                return payloadByAddingLegacyAlias(.lut1D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut1D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut1D, actual: payload.outputType)
                }

                let writeOptions = normalizedOLOptions(from: options)
                let contents = try LUTFormatterOLUT.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func quantelDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterQuantel.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "Quantel",
                "integerMaxOutput": LUTMath.maxInteger(bitDepth: 16),
                "lutSize": 33
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "Quantel",
            "integerMaxOutput": [
                LUTMath.maxInteger(bitDepth: 12),
                LUTMath.maxInteger(bitDepth: 16)
            ],
            "lutSize": [17, 33, 65]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Quantel 3D LUT",
            fileExtensions: ["txt"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.text",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["Quantel"],
            reader: { url in
                let lut = try LUTFormatterQuantel.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedQuantelOptions(from: options)
                let contents = try LUTFormatterQuantel.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func fsiDATDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterFSIDAT.formatterIdentifier
        let defaultVariant = LUTFormatterFSIDAT.Variant.v1
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": defaultVariant.rawValue,
                "lutSize": defaultVariant.lutSize
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [
            [
                "fileTypeVariant": LUTFormatterFSIDAT.Variant.v1.rawValue,
                "lutSize": [LUTFormatterFSIDAT.Variant.v1.lutSize]
            ],
            [
                "fileTypeVariant": LUTFormatterFSIDAT.Variant.v2.rawValue,
                "lutSize": [LUTFormatterFSIDAT.Variant.v2.lutSize]
            ]
        ]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "FSI DAT 3D LUT",
            fileExtensions: ["dat"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.dat-lut",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["FSIDAT"],
            reader: { url in
                let lut = try LUTFormatterFSIDAT.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedFSIDATOptions(from: options)
                    ?? LUTFormatterFSIDAT.Options.default
                let data = try LUTFormatterFSIDAT.write(lut, options: writeOptions)
                try data.write(to: url, options: .atomic)
            }
        )
    }

    private static func clipsterDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterClipster.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "Clipster",
                "lutSize": 17,
                "integerMaxOutput": LUTMath.maxInteger(bitDepth: 16)
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "Clipster",
            "lutSize": [17],
            "integerMaxOutput": [
                LUTMath.maxInteger(bitDepth: 10),
                LUTMath.maxInteger(bitDepth: 12),
                LUTMath.maxInteger(bitDepth: 16)
            ]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "DVS Clipster 3D LUT",
            fileExtensions: ["xml", "txt"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.xml",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["Clipster"],
            reader: { url in
                let lut = try LUTFormatterClipster.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedClipsterOptions(from: options)
                    ?? LUTFormatterClipster.Options()
                let contents = try LUTFormatterClipster.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func discreetDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterDiscreet1DLUT.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "Discreet",
                "integerMaxOutput": LUTMath.maxInteger(bitDepth: 12)
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "Discreet",
            "integerMaxOutput": [
                LUTMath.maxInteger(bitDepth: 12),
                LUTMath.maxInteger(bitDepth: 16)
            ]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Discreet 1D LUT",
            fileExtensions: ["lut"],
            output: .lut1D,
            roles: [.read, .write],
            uti: "com.discreet.lut",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["Discreet"],
            reader: { url in
                let lut = try LUTFormatterDiscreet1DLUT.read(url: url)
                return payloadByAddingLegacyAlias(.lut1D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut1D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut1D, actual: payload.outputType)
                }

                let writeOptions = normalizedDiscreetOptions(from: options)
                    ?? LUTFormatterDiscreet1DLUT.Options(integerMaxOutput: LUTMath.maxInteger(bitDepth: 12))
                let contents = try LUTFormatterDiscreet1DLUT.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func cmsDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterCMSTestPattern.formatterIdentifier
    let defaultMetadata = LUTFormatterCMSTestPattern.Options().formatterDictionary()
    let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultMetadata)
        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": ImageBasedFormatterVariant.tiff.rawValue,
            "bitDepth": [8, 16]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "CMS Test Pattern Image 3D LUT",
            fileExtensions: ["tiff", "tif", "png"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.image",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: [formatterID.lowercased()],
            reader: { url in
                let data = try Data(contentsOf: url)
                let lut = try LUTFormatterCMSTestPattern.read(data: data)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedCMSOptions(from: options)
                    ?? LUTFormatterCMSTestPattern.Options()

                let data: Data
                switch url.pathExtension.lowercased() {
                case "png":
                    data = try LUTFormatterCMSTestPattern.pngData(from: lut, options: writeOptions)
                default:
                    data = try LUTFormatterCMSTestPattern.data(from: lut, options: writeOptions)
                }

                try data.write(to: url, options: .atomic)
            }
        )
    }

    private static func nucodaDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterNucodaCMS.formatterIdentifier
        let defaultVariant = LUTFormatterNucodaCMS.Variant.v3
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": defaultVariant.rawValue
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": LUTFormatterNucodaCMS.Variant.v1.rawValue
        ], [
            "fileTypeVariant": LUTFormatterNucodaCMS.Variant.v2.rawValue
        ], [
            "fileTypeVariant": LUTFormatterNucodaCMS.Variant.v3.rawValue
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Nucoda CMS LUT",
            fileExtensions: ["cms"],
            output: .either,
            roles: [.read, .write],
            uti: "com.digitalvision.cms",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["Nucoda"],
            reader: { url in
                let result = try LUTFormatterNucodaCMS.read(url: url)
                switch result {
                case .lut1D(let lut):
                    return payloadByAddingLegacyAlias(.lut1D(lut), canonicalID: formatterID)
                case .lut3D(let lut):
                    return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
                }
            },
            writer: { payload, url, options in
                let result: LUTFormatterNucodaCMSResult
                switch payload {
                case .lut1D(let lut):
                    result = .lut1D(lut)
                case .lut3D(let lut):
                    result = .lut3D(lut)
                }

                let writeOptions = normalizedNucodaOptions(from: options)
                    ?? LUTFormatterNucodaCMS.Options.default
                let contents = try LUTFormatterNucodaCMS.write(result, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func resolveDATDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterResolveDAT.formatterIdentifier
    let defaultVariant: [String: Any] = ["fileTypeVariant": "Resolve"]
    let defaultOptions: [String: Any] = [formatterID: defaultVariant]
    let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)
        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "Resolve"
        ], [
            "fileTypeVariant": "DaVinci"
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Resolve DAT 3D LUT",
            fileExtensions: ["dat"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.dat-lut",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["ResolveDAT"],
            reader: { url in
                let lut = try LUTFormatterResolveDAT.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedResolveOptions(from: options)
                let contents = try LUTFormatterResolveDAT.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func davinciDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterDaVinciDAVLUT.formatterIdentifier
        let resolveKey = LUTFormatterResolveDAT.formatterIdentifier
        let defaultVariant: [String: Any] = ["fileTypeVariant": "DaVinci"]
        let defaultOptions: [String: Any] = [
            resolveKey: defaultVariant,
            formatterID: defaultVariant
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        return LUTFormatterDescriptor(
            id: formatterID,
            name: LUTFormatterDaVinciDAVLUT.formatterName(),
            fileExtensions: LUTFormatterDaVinciDAVLUT.fileExtensions(),
            output: .lut3D,
            roles: [.read, .write],
            uti: "com.blackmagicdesign.davlut",
            defaultOptions: mirroredDefaults,
            allOptions: [["fileTypeVariant": "DaVinci"]],
            alternateIdentifiers: ["DaVinci"],
            reader: { url in
                var lut = try LUTFormatterDaVinciDAVLUT.read(url: url)
                if lut.passthroughFileOptions[formatterID] == nil,
                   let resolveOptions = lut.passthroughFileOptions[resolveKey] {
                    lut.passthroughFileOptions[formatterID] = resolveOptions
                }
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedResolveOptions(from: options) ?? LUTFormatterResolveDAT.Options(fileTypeVariant: "DaVinci")
                let contents = try LUTFormatterResolveDAT.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func matchLightDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterMatchLight.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "MatchLight"
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "LightIllusion MatchLight 3D LUT",
            fileExtensions: ["mlc"],
            output: .lut3D,
            roles: [.read],
            uti: "com.lightillusion.mlc",
            defaultOptions: mirroredDefaults,
            allOptions: [["fileTypeVariant": "MatchLight"]],
            alternateIdentifiers: ["MatchLight", formatterID.lowercased()],
            reader: { url in
                let lut = try LUTFormatterMatchLight.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            }
        )
    }

    private static func arriLookDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterArriLook.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterID: [
                "fileTypeVariant": "Arri",
                "lutSize": 4096
            ]
        ]
        let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)

        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": "Arri",
            "lutSize": [4096]
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Arri Look",
            fileExtensions: ["xml"],
            output: .either,
            roles: [.read, .write],
            uti: "public.xml",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: ["arri"],
            reader: { url in
                let lut = try LUTFormatterArriLook.read(url: url)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut1D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut1D, actual: payload.outputType)
                }

                let writeOptions = normalizedArriOptions(from: options)
                    ?? LUTFormatterArriLook.Options(lutSize: 4096)
                let contents = try LUTFormatterArriLook.write(lut, options: writeOptions)
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        )
    }

    private static func unwrappedTextureDescriptor() -> LUTFormatterDescriptor {
        let formatterID = LUTFormatterUnwrappedTexture.formatterIdentifier
    let defaultMetadata = LUTFormatterUnwrappedTexture.Options().metadata()
    let defaultOptions = defaultMetadata.passthroughDictionary(formatterID: formatterID)
    let mirroredDefaults = mirroredDefaultOptions(for: formatterID, options: defaultOptions)
        let allOptions: [[String: Any]] = [[
            "fileTypeVariant": ImageBasedFormatterVariant.tiff.rawValue,
            "bitDepth": ImageBasedFormatterVariant.tiff.supportedBitDepths
        ]]

        return LUTFormatterDescriptor(
            id: formatterID,
            name: "Unwrapped Cube Image 3D LUT",
            fileExtensions: ["png", "tiff", "tif"],
            output: .lut3D,
            roles: [.read, .write],
            uti: "public.image",
            defaultOptions: mirroredDefaults,
            allOptions: allOptions,
            alternateIdentifiers: [formatterID.lowercased()],
            reader: { url in
                let data = try Data(contentsOf: url)
                let lut = try LUTFormatterUnwrappedTexture.read(data: data)
                return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: formatterID)
            },
            writer: { payload, url, options in
                guard case .lut3D(let lut) = payload else {
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: payload.outputType)
                }

                let writeOptions = normalizedUnwrappedOptions(from: options) ?? LUTFormatterUnwrappedTexture.Options()

                let data: Data
                switch url.pathExtension.lowercased() {
                case "png":
                    data = try LUTFormatterUnwrappedTexture.pngData(from: lut, options: writeOptions)
                default:
                    let image = try LUTFormatterUnwrappedTexture.image(from: lut, options: writeOptions)
                    data = try ImageBasedLUTUtilities.tiffData(from: image)
                }

                try data.write(to: url, options: .atomic)
            }
        )
    }

    private static func normalizeCubePayload(_ result: LUTCubeResult) -> LUTFormatterPayload {
        func optionsByAddingAlias(_ options: [String: Any]) -> [String: Any] {
            var updated = options
            let canonicalKey = LUTCubeFormatter.formatterIdentifier
            let legacyKey = LUTCubeFormatter.legacyFormatterIdentifier

            if let canonicalOptions = updated[canonicalKey], updated[legacyKey] == nil {
                updated[legacyKey] = canonicalOptions
            } else if let legacyOptions = updated[legacyKey], updated[canonicalKey] == nil {
                updated[canonicalKey] = legacyOptions
            }

            if let referenceOptions = updated[canonicalKey] ?? updated[legacyKey],
               updated["com.blackmagicdesign.cube"] == nil {
                updated["com.blackmagicdesign.cube"] = referenceOptions
            }

            return updated
        }

        switch result {
        case .lut1D(var lut):
            lut.passthroughFileOptions = optionsByAddingAlias(lut.passthroughFileOptions)
            return payloadByAddingLegacyAlias(.lut1D(lut), canonicalID: LUTCubeFormatter.formatterIdentifier)
        case .lut3D(var lut):
            lut.passthroughFileOptions = optionsByAddingAlias(lut.passthroughFileOptions)
            return payloadByAddingLegacyAlias(.lut3D(lut), canonicalID: LUTCubeFormatter.formatterIdentifier)
        }
    }

    private static func normalizedCubeOptions(from options: [String: Any]?) -> LUTCubeOptions? {
        guard let options else { return nil }
        let candidateKeys = [
            LUTCubeFormatter.formatterIdentifier,
            "cube",
            LUTCubeFormatter.legacyFormatterIdentifier,
            "com.blackmagicdesign.cube"
        ]
        for key in candidateKeys {
            if let variantDict = options[key] as? [String: Any],
               let rawValue = variantDict["fileTypeVariant"] as? String,
               let variant = LUTCubeVariant(rawValue: rawValue) {
                return LUTCubeOptions(variant: variant)
            }
        }

        if let rawValue = options["fileTypeVariant"] as? String,
           let variant = LUTCubeVariant(rawValue: rawValue) {
            return LUTCubeOptions(variant: variant)
        }

        return nil
    }

    private static func normalized3DLOptions(from options: [String: Any]?) -> LUTFormatter3DL.Options? {
        guard let options else { return nil }
        let legacyKey = legacyIdentifier(for: LUTFormatter3DL.formatterIdentifier)
        let candidateKeys = [LUTFormatter3DL.formatterIdentifier, legacyKey, "autodesk3dl"]
        var formatterOptions: [String: Any]? = options
        for key in candidateKeys {
            if let nested = options[key] as? [String: Any] {
                formatterOptions = nested
                break
            }
        }

        guard let rawVariant = formatterOptions?["fileTypeVariant"] as? String,
              let variant = LUTFormatter3DL.Variant(rawValue: rawVariant) else {
            return nil
        }

        guard let integerMax = integerValue(from: formatterOptions?["integerMaxOutput"]) else {
            return nil
        }

        return LUTFormatter3DL.Options(variant: variant, integerMaxOutput: integerMax)
    }

    private static func integerValue(from value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as Double:
            return Int(value)
        case let value as Float:
            return Int(value)
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private static func normalizedHaldOptions(from options: [String: Any]?) -> LUTFormatterHaldCLUT.Options? {
        guard let options else { return nil }

        if let parsed = LUTFormatterHaldCLUT.Options.from(passthrough: options) {
            return parsed
        }

        if let bitDepth = integerValue(from: options["bitDepth"]) {
            return LUTFormatterHaldCLUT.Options(bitDepth: bitDepth)
        }

        let candidateKeys = [
            LUTFormatterHaldCLUT.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterHaldCLUT.formatterIdentifier)
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any] {
                let payload = [LUTFormatterHaldCLUT.formatterIdentifier: nested]
                if let parsed = LUTFormatterHaldCLUT.Options.from(passthrough: payload) {
                    return parsed
                }
            }
        }

        return nil
    }

    private static func normalizedUnwrappedOptions(from options: [String: Any]?) -> LUTFormatterUnwrappedTexture.Options? {
        guard let options else { return nil }

        if let parsed = LUTFormatterUnwrappedTexture.Options.from(passthrough: options) {
            return parsed
        }

        let candidateKeys = [
            LUTFormatterUnwrappedTexture.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterUnwrappedTexture.formatterIdentifier)
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any] {
                let payload = [LUTFormatterUnwrappedTexture.formatterIdentifier: nested]
                if let parsed = LUTFormatterUnwrappedTexture.Options.from(passthrough: payload) {
                    return parsed
                }
            }
        }

        if let bitDepth = integerValue(from: options["bitDepth"]) {
            return LUTFormatterUnwrappedTexture.Options(bitDepth: bitDepth)
        }

        return nil
    }

    private static func normalizedOLOptions(from options: [String: Any]?) -> LUTFormatterOLUT.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterOLUT.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterOLUT.formatterIdentifier)
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let lutSize = integerValue(from: nested["lutSize"]) {
                return LUTFormatterOLUT.Options(lutSize: lutSize)
            }
        }

        if let lutSize = integerValue(from: options["lutSize"]) {
            return LUTFormatterOLUT.Options(lutSize: lutSize)
        }

        return nil
    }

    private static func normalizedQuantelOptions(from options: [String: Any]?) -> LUTFormatterQuantel.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterQuantel.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterQuantel.formatterIdentifier),
            "Quantel"
        ]
        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let integerMax = integerValue(from: nested["integerMaxOutput"]),
               let lutSize = integerValue(from: nested["lutSize"]) {
                return LUTFormatterQuantel.Options(integerMaxOutput: integerMax, lutSize: lutSize)
            }
        }

        if let integerMax = integerValue(from: options["integerMaxOutput"]),
           let lutSize = integerValue(from: options["lutSize"]) {
            return LUTFormatterQuantel.Options(integerMaxOutput: integerMax, lutSize: lutSize)
        }

        return nil
    }

    private static func normalizedResolveOptions(from options: [String: Any]?) -> LUTFormatterResolveDAT.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterResolveDAT.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterResolveDAT.formatterIdentifier),
            LUTFormatterDaVinciDAVLUT.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterDaVinciDAVLUT.formatterIdentifier),
            "ResolveDAT",
            "DaVinci"
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let variant = nested["fileTypeVariant"] as? String {
                return LUTFormatterResolveDAT.Options(fileTypeVariant: variant)
            }
        }

        if let variant = options["fileTypeVariant"] as? String {
            return LUTFormatterResolveDAT.Options(fileTypeVariant: variant)
        }

        return nil
    }

    private static func normalizedFSIDATOptions(from options: [String: Any]?) -> LUTFormatterFSIDAT.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterFSIDAT.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterFSIDAT.formatterIdentifier),
            "fsiDAT",
            "FSIDAT"
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let rawVariant = nested["fileTypeVariant"] as? String,
               let variant = LUTFormatterFSIDAT.Variant(rawValue: rawVariant) {
                return LUTFormatterFSIDAT.Options(variant: variant)
            }
        }

        if let rawVariant = options["fileTypeVariant"] as? String,
           let variant = LUTFormatterFSIDAT.Variant(rawValue: rawVariant) {
            return LUTFormatterFSIDAT.Options(variant: variant)
        }

        return nil
    }

    private static func normalizedClipsterOptions(from options: [String: Any]?) -> LUTFormatterClipster.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterClipster.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterClipster.formatterIdentifier),
            "clipster"
        ]
        for key in candidateKeys {
            if let nested = options[key] as? [String: Any] {
                let lutSize = integerValue(from: nested["lutSize"]) ?? 17
                let integerMax = integerValue(from: nested["integerMaxOutput"]) ?? LUTMath.maxInteger(bitDepth: 16)
                return LUTFormatterClipster.Options(lutSize: lutSize, integerMaxOutput: integerMax)
            }
        }

        if let lutSize = integerValue(from: options["lutSize"]) {
            let integerMax = integerValue(from: options["integerMaxOutput"]) ?? LUTMath.maxInteger(bitDepth: 16)
            return LUTFormatterClipster.Options(lutSize: lutSize, integerMaxOutput: integerMax)
        }

        if let integerMax = integerValue(from: options["integerMaxOutput"]) {
            return LUTFormatterClipster.Options(integerMaxOutput: integerMax)
        }

        return nil
    }

    private static func normalizedDiscreetOptions(from options: [String: Any]?) -> LUTFormatterDiscreet1DLUT.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterDiscreet1DLUT.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterDiscreet1DLUT.formatterIdentifier),
            "Discreet"
        ]
        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let integerMax = integerValue(from: nested["integerMaxOutput"]) {
                return LUTFormatterDiscreet1DLUT.Options(integerMaxOutput: integerMax)
            }
        }

        if let integerMax = integerValue(from: options["integerMaxOutput"]) {
            return LUTFormatterDiscreet1DLUT.Options(integerMaxOutput: integerMax)
        }

        return nil
    }

    private static func normalizedCMSOptions(from options: [String: Any]?) -> LUTFormatterCMSTestPattern.Options? {
        guard let options else { return nil }

        if let parsed = LUTFormatterCMSTestPattern.Options.from(passthrough: options) {
            return parsed
        }

        let candidateKeys = [
            LUTFormatterCMSTestPattern.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterCMSTestPattern.formatterIdentifier)
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any] {
                let payload = [LUTFormatterCMSTestPattern.formatterIdentifier: nested]
                if let parsed = LUTFormatterCMSTestPattern.Options.from(passthrough: payload) {
                    return parsed
                }
            }
        }

        let variant: ImageBasedFormatterVariant?
        if let variantName = options["fileTypeVariant"] as? String {
            variant = ImageBasedFormatterVariant(rawValue: variantName)
        } else {
            variant = nil
        }

        if let bitDepth = integerValue(from: options["bitDepth"]) {
            if let variant {
                return LUTFormatterCMSTestPattern.Options(bitDepth: bitDepth, variant: variant)
            }
            return LUTFormatterCMSTestPattern.Options(bitDepth: bitDepth)
        }

        return nil
    }

    private static func normalizedNucodaOptions(from options: [String: Any]?) -> LUTFormatterNucodaCMS.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterNucodaCMS.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterNucodaCMS.formatterIdentifier),
            "Nucoda"
        ]

        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let rawVariant = nested["fileTypeVariant"] as? String,
               let variant = LUTFormatterNucodaCMS.Variant(rawValue: rawVariant) {
                return LUTFormatterNucodaCMS.Options(variant: variant)
            }
        }

        if let rawVariant = options["fileTypeVariant"] as? String,
           let variant = LUTFormatterNucodaCMS.Variant(rawValue: rawVariant) {
            return LUTFormatterNucodaCMS.Options(variant: variant)
        }

        return nil
    }

    private static func normalizedArriOptions(from options: [String: Any]?) -> LUTFormatterArriLook.Options? {
        guard let options else { return nil }

        let candidateKeys = [
            LUTFormatterArriLook.formatterIdentifier,
            legacyIdentifier(for: LUTFormatterArriLook.formatterIdentifier),
            "arri"
        ]
        for key in candidateKeys {
            if let nested = options[key] as? [String: Any],
               let lutSize = integerValue(from: nested["lutSize"]) {
                return LUTFormatterArriLook.Options(lutSize: lutSize)
            }
        }

        if let lutSize = integerValue(from: options["lutSize"]) {
            return LUTFormatterArriLook.Options(lutSize: lutSize)
        }

        return nil
    }
}

public enum CocoaLUT {
    public enum Error: Swift.Error, LocalizedError {
        case formatterNotFound(String)
        case readUnsupportedFormatter(String)
        case writeUnsupportedFormatter(String)
        case invalidPayload(expected: LUTFormatterOutputType, actual: LUTFormatterOutputType)

        public var errorDescription: String? {
            switch self {
            case .formatterNotFound(let id):
                return "No formatter registered with identifier \(id)."
            case .readUnsupportedFormatter(let id):
                return "Formatter \(id) does not support reading."
            case .writeUnsupportedFormatter(let id):
                return "Formatter \(id) does not support writing."
            case .invalidPayload(let expected, let actual):
                return "Formatter expected payload type \(expected.rawValue) but received \(actual.rawValue)."
            }
        }
    }

    public static let suggestedMaxLUT1DSize = LUTConstants.suggestedMax1DSize
    public static let suggestedMaxLUT3DSize = LUTConstants.suggestedMax3DSize
    public static let maxCIColorCubeSize = LUTConstants.maxCIColorCubeSize
    public static let maxVVLUT1DFilterSize = LUTConstants.maxVVLUT1DFilterSize

    public static func descriptor(for identifier: String) throws -> LUTFormatterDescriptor {
        guard let descriptor = LUTFormatterRegistry.descriptor(for: identifier) else {
            throw Error.formatterNotFound(identifier)
        }
        return descriptor
    }

    public static func descriptors(forFileExtension ext: String) -> [LUTFormatterDescriptor] {
        LUTFormatterRegistry.descriptors(forFileExtension: ext)
    }

    public static func read(from url: URL, formatterIdentifier: String? = nil) throws -> LUTFormatterPayload {
        if let formatterIdentifier {
            let descriptor = try descriptor(for: formatterIdentifier)
            return try descriptor.read(url: url)
        }

        let matches = descriptors(forFileExtension: url.pathExtension)
        guard !matches.isEmpty else {
            throw Error.formatterNotFound(url.pathExtension)
        }

        var lastError: Swift.Error?
        for descriptor in matches where descriptor.roles.contains(.read) {
            do {
                return try descriptor.read(url: url)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? Error.readUnsupportedFormatter(url.pathExtension)
    }

    public static func write(_ payload: LUTFormatterPayload,
                             to url: URL,
                             formatterIdentifier: String,
                             options: [String: Any]? = nil) throws {
        let descriptor = try descriptor(for: formatterIdentifier)
        guard descriptor.roles.contains(.write) else {
            throw Error.writeUnsupportedFormatter(formatterIdentifier)
        }
        if descriptor.output != .either && descriptor.output != payload.outputType {
            throw Error.invalidPayload(expected: descriptor.output, actual: payload.outputType)
        }
        let effectiveOptions = options ?? payload.passthroughFileOptions
        try descriptor.write(payload, to: url, options: effectiveOptions.isEmpty ? nil : effectiveOptions)
    }
}
