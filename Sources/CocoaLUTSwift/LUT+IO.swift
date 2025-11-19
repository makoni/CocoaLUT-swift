import Foundation

extension LUT {
    /// Returns a new `LUT` by reading the contents of a file represented by a file URL.
    /// It will automatically detect the type of LUT file format.
    ///
    /// - Parameter url: A file URL.
    /// - Returns: A new `LUT` with the contents of url.
    /// - Throws: `CocoaLUT.Error` if the file cannot be read or is not a 3D LUT.
    public static func from(url: URL) throws -> LUT {
        let ext = url.pathExtension
        let descriptors = CocoaLUT.descriptors(forFileExtension: ext)
        
        var lastError: Error?
        
        for descriptor in descriptors {
            do {
                let payload = try descriptor.read(url: url)
                switch payload {
                case .lut3D(let lut3d):
                    return lut3d.asLUT()
                case .lut1D:
                    // If we found a valid 1D LUT, but we are asking for a 3D LUT (LUT struct),
                    // we should probably stop and say type mismatch, unless we want to convert?
                    // For now, let's treat it as "not a 3D LUT".
                    throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: .lut1D)
                }
            } catch {
                lastError = error
            }
        }
        
        if let lastError = lastError {
            throw lastError
        }
        
        throw CocoaLUT.Error.formatterNotFound("No suitable formatter found for extension .\(ext)")
    }
    
    /// Initializes a new `LUT` by reading the contents of a file represented by a file URL.
    /// It will automatically detect the type of LUT file format.
    ///
    /// - Parameter url: A file URL.
    /// - Throws: `CocoaLUT.Error` if the file cannot be read or is not a 3D LUT.
    public init(url: URL) throws {
        self = try LUT.from(url: url)
    }

    /// Saves the LUT to a file at the specified URL, automatically selecting a formatter based on the file extension.
    ///
    /// - Parameters:
    ///   - url: The file URL to write to.
    ///   - options: Optional settings for the formatter.
    /// - Throws: `CocoaLUT.Error` if no suitable formatter is found or writing fails.
    public func save(to url: URL, options: [String: Any]? = nil) throws {
        let ext = url.pathExtension.lowercased()
        let descriptors = CocoaLUT.descriptors(forFileExtension: ext)
        
        for descriptor in descriptors {
            if descriptor.roles.contains(.write) {
                try write(to: url, formatterID: descriptor.id, options: options ?? [:])
                return
            }
        }
        
        throw CocoaLUT.Error.formatterNotFound("No suitable writer found for extension .\(ext)")
    }

    /// Initializes a new `LUT` from data using a specific formatter.
    ///
    /// - Parameters:
    ///   - data: The data to load.
    ///   - formatterID: The identifier of the formatter to use.
    /// - Throws: `CocoaLUT.Error` if the formatter is not found or reading fails.
    public init(data: Data, formatterID: String) throws {
        guard let descriptor = try? CocoaLUT.descriptor(for: formatterID) else {
            throw CocoaLUT.Error.formatterNotFound("No formatter found with ID \(formatterID)")
        }
        
        // Write data to a temporary file to use the URL-based reader
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let payload = try descriptor.read(url: tempURL)
        switch payload {
        case .lut3D(let lut3d):
            self = lut3d.asLUT()
        case .lut1D:
            throw CocoaLUT.Error.invalidPayload(expected: .lut3D, actual: .lut1D)
        }
    }

    /// Writes the LUT to a file at the specified URL using a specific formatter.
    ///
    /// - Parameters:
    ///   - url: The destination URL.
    ///   - formatterID: The identifier of the formatter to use.
    ///   - options: Additional options for the formatter.
    /// - Throws: `CocoaLUT.Error` if the formatter is not found or writing fails.
    public func write(to url: URL, formatterID: String, options: [String: Any] = [:]) throws {
        guard let descriptor = try? CocoaLUT.descriptor(for: formatterID) else {
            throw CocoaLUT.Error.formatterNotFound("No formatter found with ID \(formatterID)")
        }
        
        let lut3d = LUT3D(lattice: self)
        try descriptor.write(.lut3D(lut3d), to: url, options: options)
    }
}
