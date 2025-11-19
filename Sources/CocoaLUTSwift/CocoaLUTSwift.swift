// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

/// Top-level entry points for the Swift CocoaLUT package.
///
/// This facade replaces the Objective-C `CocoaLUT.h` macros with strongly typed
/// Swift constants and helper methods for locating formatter descriptors and
/// performing LUT IO.
public enum CocoaLUT {
	/// Errors thrown by facade helpers.
	public enum Error: Swift.Error, LocalizedError {
		case formatterNotFound(String)
		case readUnsupportedFormatter(String)
		case writeUnsupportedFormatter(String)
		case invalidPayload(expected: LUTFormatterOutputType, actual: LUTFormatterOutputType)
        case invalidFormat(String)

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
            case .invalidFormat(let reason):
                return "Invalid format: \(reason)"
			}
		}
	}

	/// Suggested maximum lattice size for 1D LUTs.
	public static let suggestedMaxLUT1DSize = LUTConstants.suggestedMax1DSize
	/// Suggested maximum lattice size for 3D LUTs.
	public static let suggestedMaxLUT3DSize = LUTConstants.suggestedMax3DSize
	/// Maximum size supported by `CIColorCube`.
	public static let maxCIColorCubeSize = LUTConstants.maxCIColorCubeSize
	/// Maximum size supported by the VV LUT 1D filter.
	public static let maxVVLUT1DFilterSize = LUTConstants.maxVVLUT1DFilterSize

	/// Returns the descriptor for the supplied identifier, throwing if the
	/// identifier is not registered.
	public static func descriptor(for identifier: String) throws -> LUTFormatterDescriptor {
		guard let descriptor = LUTFormatterRegistry.descriptor(for: identifier) else {
			throw Error.formatterNotFound(identifier)
		}
		return descriptor
	}

	/// Returns all descriptors that match the supplied file extension.
	public static func descriptors(forFileExtension ext: String) -> [LUTFormatterDescriptor] {
		LUTFormatterRegistry.descriptors(forFileExtension: ext)
	}

	/// Returns all registered formatter descriptors.
	public static func allDescriptors() -> [LUTFormatterDescriptor] {
		LUTFormatterRegistry.descriptors()
	}

	/// Reads a LUT payload from disk using the supplied formatter identifier.
	/// When no identifier is provided, the registry is consulted using the
	/// file extension.
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

	/// Writes the payload to disk using the supplied formatter identifier.
	/// Formatter-specific options fall back to the payload's passthrough
	/// dictionary when no explicit options are provided.
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

