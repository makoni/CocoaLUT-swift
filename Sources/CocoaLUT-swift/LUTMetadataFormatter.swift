import Foundation

enum LUTMetadataFormatter {
    static func metadataAndDescription(from lines: [String]) -> (metadata: [String: Any], description: String?) {
        let descriptionLines = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("#") }
            .map { line in
                line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            }
            .filter { !$0.isEmpty }

        return ([:], descriptionLines.isEmpty ? nil : descriptionLines.joined(separator: "\n"))
    }

    static func string(from metadata: [String: Any], description: String?) -> String {
        var lines: [String] = []

        if let description, !description.isEmpty {
            description
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .forEach { lines.append("# \($0)") }
        }

        if !metadata.isEmpty {
            let formattedMetadata = metadata
                .sorted { $0.key < $1.key }
                .map { "# \($0.key): \($0.value)" }
            lines.append(contentsOf: formattedMetadata)
        }

        return lines.joined(separator: "\n")
    }
}
