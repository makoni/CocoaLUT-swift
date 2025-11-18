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
    
    /// Writes the LUT to a file at the specified URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to write to.
    ///   - formatterID: The identifier of the formatter to use.
    ///   - options: Optional settings for the formatter.
    /// - Throws: `CocoaLUT.Error` if the formatter is not found or writing fails.
    public func write(to url: URL, formatterID: String, options: [String: Any]? = nil) throws {
        let descriptor = try CocoaLUT.descriptor(for: formatterID)
        let payload = LUTFormatterPayload.lut3D(LUT3D(lattice: self))
        try descriptor.write(payload, to: url, options: options)
    }
}
