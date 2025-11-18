import Foundation

enum LUTFormatterFSIDATError: Error, Equatable, LocalizedError {
    case invalidFile
    case unsupportedVersion(UInt32)
    case unexpectedLength(expected: Int, actual: Int)
    case invalidLUTSize(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "The provided data is not a valid FSI DAT LUT."
        case .unsupportedVersion(let version):
            return String(format: "Unsupported FSI DAT version 0x%08X.", version)
        case .unexpectedLength(let expected, let actual):
            return "FSI DAT payload length mismatch. Expected \(expected) bytes, found \(actual)."
        case .invalidLUTSize(let expected, let actual):
            return "FSI DAT requires a LUT of size \(expected), but received \(actual)."
        }
    }
}

enum LUTFormatterFSIDAT {
    static let formatterIdentifier = "fsiDAT"

    enum Variant: String {
        case v1
        case v2

        var lutSize: Int {
            switch self {
            case .v1: return 64
            case .v2: return 17
            }
        }

        var versionField: UInt32 {
            switch self {
            case .v1: return 0x0100_0002
            case .v2: return 0x0200_0000
            }
        }

        var dataScale: Double {
            switch self {
            case .v1: return 1008.0
            case .v2: return 1023.0
            }
        }

        static func from(versionField: UInt32) throws -> Variant {
            if versionField < 0x0200_0000 {
                return .v1
            } else if versionField == 0x0200_0000 {
                return .v2
            }
            throw LUTFormatterFSIDATError.unsupportedVersion(versionField)
        }
    }

    struct Options {
        var variant: Variant

        static let `default` = Options(variant: .v1)
    }

    // MARK: Reading

    static func read(url: URL) throws -> LUT3D {
        let data = try Data(contentsOf: url)
        return try read(data: data)
    }

    static func read(data: Data) throws -> LUT3D {
        guard data.count >= 128 else { throw LUTFormatterFSIDATError.invalidFile }
        let headerData = data.prefix(128)
        let payload = data.suffix(from: 128)
        let header = try FileHeader(data: headerData)
        let variant = try Variant.from(versionField: header.versionRaw)
        let expectedLength = variant.lutSize * variant.lutSize * variant.lutSize * MemoryLayout<UInt32>.size
        guard payload.count == expectedLength else {
            throw LUTFormatterFSIDATError.unexpectedLength(expected: expectedLength, actual: payload.count)
        }

        var lut = LUT3D(size: variant.lutSize,
                        inputLowerBound: 0,
                        inputUpperBound: 1)

        payload.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt32.self)
            for (index, value) in buffer.enumerated() {
                let unpacked: UInt32
                switch variant {
                case .v1:
                    unpacked = UInt32(littleEndian: value)
                case .v2:
                    unpacked = UInt32(bigEndian: value)
                }

                let red = Double(unpacked & 0x3FF) / variant.dataScale
                let green = Double((unpacked >> 10) & 0x3FF) / variant.dataScale
                let blue = Double((unpacked >> 20) & 0x3FF) / variant.dataScale

                let r = index % variant.lutSize
                let g = (index % (variant.lutSize * variant.lutSize)) / variant.lutSize
                let b = index / (variant.lutSize * variant.lutSize)
                lut.setColor(LUTColor.color(red: red, green: green, blue: blue),
                             r: r, g: g, b: b)
            }
        }

        lut.title = header.name
        lut.descriptionText = header.description
        var metadata: [String: Any] = [:]
        if !header.version.isEmpty { metadata["version"] = header.version }
        if !header.model.isEmpty { metadata["model"] = header.model }
        lut.metadata = metadata
        lut.passthroughFileOptions = passthroughOptions(for: variant)
        return lut
    }

    // MARK: Writing

    static func write(_ lut: LUT3D, options: Options? = nil) throws -> Data {
        let resolvedOptions = options
            ?? optionsFromPassthrough(lut.passthroughFileOptions)
            ?? .default
        let variant = resolvedOptions.variant
        guard lut.size == variant.lutSize else {
            throw LUTFormatterFSIDATError.invalidLUTSize(expected: variant.lutSize, actual: lut.size)
        }

        var payload = Data(count: variant.lutSize * variant.lutSize * variant.lutSize * MemoryLayout<UInt32>.size)
        payload.withUnsafeMutableBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt32.self)
            for index in 0..<buffer.count {
                let r = index % variant.lutSize
                let g = (index % (variant.lutSize * variant.lutSize)) / variant.lutSize
                let b = index / (variant.lutSize * variant.lutSize)
                let color = lut.colorAt(r: r, g: g, b: b)

                let red = Self.quantize(color.red, scale: variant.dataScale, rounded: variant == .v2)
                let green = Self.quantize(color.green, scale: variant.dataScale, rounded: variant == .v2)
                let blue = Self.quantize(color.blue, scale: variant.dataScale, rounded: variant == .v2)

                var packed = UInt32(red)
                packed |= UInt32(green) << 10
                packed |= UInt32(blue) << 20

                switch variant {
                case .v1:
                    buffer[index] = packed.littleEndian
                case .v2:
                    buffer[index] = packed.bigEndian
                }
            }
        }

        let header = FileHeader(variant: variant,
                                title: lut.title ?? "",
                                description: lut.descriptionText ?? "",
                                model: lut.metadata["model"] as? String ?? "",
                                version: lut.metadata["version"] as? String ?? "",
                                payload: payload)

        var data = Data()
        data.append(header.serialized())
        data.append(payload)
        return data
    }
}

// MARK: - Private Helpers

private extension LUTFormatterFSIDAT {
    static func quantize(_ value: Double, scale: Double, rounded: Bool) -> UInt32 {
        let clamped = LUTMath.clamp01(value)
        let scaled = clamped * scale
        if rounded {
            return UInt32((scaled).rounded())
        } else {
            return UInt32(scaled)
        }
    }

    static func passthroughOptions(for variant: Variant) -> [String: Any] {
        [formatterIdentifier: ["fileTypeVariant": variant.rawValue,
                               "lutSize": variant.lutSize]]
    }

    static func optionsFromPassthrough(_ options: [String: Any]) -> Options? {
        guard let formatterOptions = options[formatterIdentifier] as? [String: Any],
              let variantName = formatterOptions["fileTypeVariant"] as? String,
              let variant = Variant(rawValue: variantName) else {
            return nil
        }
        return Options(variant: variant)
    }
}

// MARK: - File Header

private struct FileHeader {
    let magic: UInt32
    let versionRaw: UInt32
    let model: String
    let version: String
    let dataChecksum: UInt32
    let length: UInt32
    let description: String
    let reserved2: UInt32
    let name: String
    let headerChecksum: UInt8

    static let magicConstant: UInt32 = 0x4234_0299

    init(data: Data) throws {
        guard data.count == 128 else { throw LUTFormatterFSIDATError.invalidFile }
        var offset = 0

        func readUInt32() -> UInt32 {
            defer { offset += 4 }
            return data.withUnsafeBytes { buffer in
                let value = buffer.load(fromByteOffset: offset, as: UInt32.self)
                return UInt32(littleEndian: value)
            }
        }

        func readBytes(count: Int) -> Data {
            let range = offset..<(offset + count)
            let slice = data.subdata(in: range)
            offset += count
            return slice
        }

        func decodeString(_ bytes: Data) -> String {
            if let firstNull = bytes.firstIndex(of: 0) {
                return String(bytes: bytes.prefix(upTo: firstNull), encoding: .utf8) ?? ""
            }
            return String(bytes: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        magic = readUInt32()
        versionRaw = readUInt32()
        model = decodeString(readBytes(count: 16))
        version = decodeString(readBytes(count: 16))
        dataChecksum = readUInt32()
        length = readUInt32()
        description = decodeString(readBytes(count: 16))
        reserved2 = readUInt32()
        name = decodeString(readBytes(count: 16))
        _ = readBytes(count: 43) // reserved
        headerChecksum = readBytes(count: 1).first ?? 0

        guard magic == FileHeader.magicConstant else {
            throw LUTFormatterFSIDATError.invalidFile
        }
    }

    init(variant: LUTFormatterFSIDAT.Variant,
         title: String,
         description: String,
         model: String,
         version: String,
         payload: Data) {
        self.magic = FileHeader.magicConstant
        self.versionRaw = variant.versionField
        self.model = model
        self.version = version
        self.dataChecksum = payload.reduce(UInt32(0)) { $0 + UInt32($1) }
        self.length = UInt32(payload.count)
        self.description = description
        self.reserved2 = 0
        self.name = title
        self.headerChecksum = 0 // placeholder, computed during serialization
    }

    func serialized() -> Data {
        var data = Data(count: 128)
        data.withUnsafeMutableBytes { mutableRawBuffer in
            func writeUInt32(_ value: UInt32, at offset: inout Int) {
                var little = value.littleEndian
                withUnsafeBytes(of: &little) { bytes in
                    mutableRawBuffer[offset..<(offset + 4)].copyBytes(from: bytes)
                }
                offset += 4
            }

            func writeString(_ string: String, count: Int, at offset: inout Int) {
                var bytes = Array(string.utf8.prefix(count))
                if bytes.count < count {
                    bytes.append(contentsOf: Array(repeating: 0, count: count - bytes.count))
                }
                mutableRawBuffer[offset..<(offset + count)].copyBytes(from: bytes)
                offset += count
            }

            var cursor = 0
            writeUInt32(magic, at: &cursor)
            writeUInt32(versionRaw, at: &cursor)
            writeString(model, count: 16, at: &cursor)
            writeString(version, count: 16, at: &cursor)
            writeUInt32(dataChecksum, at: &cursor)
            writeUInt32(length, at: &cursor)
            writeString(description, count: 16, at: &cursor)
            writeUInt32(reserved2, at: &cursor)
            writeString(name, count: 16, at: &cursor)
            let reservedBytes = Array(repeating: UInt8(0), count: 43)
            mutableRawBuffer[cursor..<(cursor + reservedBytes.count)].copyBytes(from: reservedBytes)
            cursor += reservedBytes.count

            // Placeholder for checksum, overwritten below
            mutableRawBuffer[cursor] = 0
        }

        var checksum: UInt32 = 0
        let byteCount = versionRaw < 0x0200_0000 ? 127 : 128
        data.withUnsafeBytes { buffer in
            for index in 0..<byteCount {
                checksum += UInt32(buffer[index])
            }
        }
        var finalized = data
        finalized[127] = UInt8(checksum & 0xFF)
        return finalized
    }
}
