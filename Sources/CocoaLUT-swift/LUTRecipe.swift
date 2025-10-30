import Foundation

public enum LUTRecipeError: Error {
    case stringEncodingFailed
}

public final class LUTRecipe {
    private var actions: [LUTAction]

    public init(actions: [LUTAction]) {
        self.actions = actions
    }

    public static func recipe(actions: [LUTAction]) -> LUTRecipe {
        LUTRecipe(actions: actions)
    }

    private func serializableArray() -> [[String: Any]] {
        actions.map { action in
            action.actionMetadata.orderedKeys.reduce(into: [String: Any]()) { result, key in
                if let value = action.actionMetadata.value(for: key) {
                    result[key] = value
                }
            }
        }
    }

    public func serializedRecipe(prettyPrinted: Bool = true) throws -> Data {
        let array = serializableArray()
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted] : []
        return try JSONSerialization.data(withJSONObject: array, options: options)
    }

    public func serializedRecipeString(prettyPrinted: Bool = true) throws -> String {
        let data = try serializedRecipe(prettyPrinted: prettyPrinted)
        guard let string = String(data: data, encoding: .utf8) else {
            throw LUTRecipeError.stringEncodingFailed
        }
        return string
    }
}
