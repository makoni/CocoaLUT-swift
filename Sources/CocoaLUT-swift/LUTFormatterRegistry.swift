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
        [cubeDescriptor(), threeDLDescriptor()]
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
        let cubeKey = "cube"
        let formatterKey = LUTCubeFormatter.formatterIdentifier
        let defaultOptions: [String: Any] = [
            formatterKey: ["fileTypeVariant": defaultVariant],
            cubeKey: ["fileTypeVariant": defaultVariant]
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
            alternateIdentifiers: [formatterKey, "com.blackmagicdesign.cube"],
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
            defaultOptions: defaultOptions,
            allOptions: allOptions,
            alternateIdentifiers: ["com.autodesk.3dl"],
            reader: { url in
                let lut = try LUTFormatter3DL.read(url: url)
                return .lut3D(lut)
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

    private static func normalizeCubePayload(_ result: LUTCubeResult) -> LUTFormatterPayload {
        func optionsByAddingAlias(_ options: [String: Any]) -> [String: Any] {
            var updated = options
            let formatterKey = LUTCubeFormatter.formatterIdentifier
            let cubeKey = "cube"
            if let formatterOptions = options[formatterKey], updated[cubeKey] == nil {
                updated[cubeKey] = formatterOptions
            }
            return updated
        }

        switch result {
        case .lut1D(var lut):
            lut.passthroughFileOptions = optionsByAddingAlias(lut.passthroughFileOptions)
            return .lut1D(lut)
        case .lut3D(var lut):
            lut.passthroughFileOptions = optionsByAddingAlias(lut.passthroughFileOptions)
            return .lut3D(lut)
        }
    }

    private static func normalizedCubeOptions(from options: [String: Any]?) -> LUTCubeOptions? {
        guard let options else { return nil }
        let candidateKeys = [LUTCubeFormatter.formatterIdentifier, "cube"]
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
    let candidateKeys = [LUTFormatter3DL.formatterIdentifier, "autodesk3dl"]
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
        try descriptor.write(payload, to: url, options: options)
    }
}
