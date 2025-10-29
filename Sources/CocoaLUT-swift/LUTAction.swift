import Foundation

public struct LUTActionMetadata: Sequence {
    private var entries: [(key: String, value: Any)]

    public init(entries: [(String, Any)] = []) {
        self.entries = []
        entries.forEach { appendOrUpdate(key: $0.0, value: $0.1) }
    }

    public func value(for key: String) -> Any? {
        entries.first { $0.key == key }?.value
    }

    public var orderedKeys: [String] {
        entries.map { $0.key }
    }

    public var dictionary: [String: Any] {
        entries.reduce(into: [:]) { result, element in
            result[element.key] = element.value
        }
    }

    public func makeIterator() -> IndexingIterator<[(key: String, value: Any)]> {
        entries.makeIterator()
    }

    internal func adding(key: String, value: Any) -> LUTActionMetadata {
        var copy = self
        copy.appendOrUpdate(key: key, value: value)
        return copy
    }

    private mutating func appendOrUpdate(key: String, value: Any) {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries[index].value = value
        } else {
            entries.append((key: key, value: value))
        }
    }
}

public final class LUTAction: NSObject, NSCopying {
    public typealias ActionBlock = (LUT) -> LUT

    public let actionBlock: ActionBlock
    public let actionName: String
    public let actionMetadata: LUTActionMetadata

    private var cachedInput: LUT?
    private var cachedOutput: LUT?

    public init(actionBlock: @escaping ActionBlock,
                actionName: String,
                actionMetadata: LUTActionMetadata) {
        precondition(!actionName.isEmpty, "Action name must not be empty")
        self.actionBlock = actionBlock
        self.actionName = actionName
        self.actionMetadata = actionMetadata
    }

    public static func action(with block: @escaping ActionBlock,
                              name: String,
                              metadataEntries: [(String, Any)]) -> LUTAction {
        LUTAction(actionBlock: block,
                  actionName: name,
                  actionMetadata: LUTActionMetadata(entries: metadataEntries))
    }

    public static func bypass(named name: String) -> LUTAction {
        action(with: { $0 },
               name: name,
               metadataEntries: [("id", "Bypass")])
    }


    public static func changeInputBounds(lower: Double,
                                         upper: Double,
                                         name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ChangeInputBounds"),
            ("inputLowerBound", lower),
            ("inputUpperBound", upper)
        ])
        return LUTAction(actionBlock: { $0.changingInputBounds(lower: lower, upper: upper) },
                         actionName: name ?? "Change Input Bounds",
                         actionMetadata: metadata)
    }

    public static func clamp(lower: Double,
                             upper: Double,
                             name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "Clamp"),
            ("lowerBound", lower),
            ("upperBound", upper)
        ])
        return LUTAction(actionBlock: { $0.clamped(lower: lower, upper: upper) },
                         actionName: name ?? "Clamp",
                         actionMetadata: metadata)
    }

    public static func resize(to size: Int,
                               name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "Resize"),
            ("size", size)
        ])
        return LUTAction(actionBlock: { $0.resized(to: size) },
                         actionName: name ?? "Resize",
                         actionMetadata: metadata)
    }

    public static func scaleToUnitRange(name: String? = nil) -> LUTAction {
        let metadata = LUTActionMetadata(entries: [
            ("id", "ScaleTo01")
        ])
        return LUTAction(actionBlock: { $0.scaledTo01() },
                         actionName: name ?? "Scale 0 to 1",
                         actionMetadata: metadata)
    }

    public func apply(to lut: LUT) -> LUT {
        if let cachedInput, let cachedOutput,
           cachedInput.equals(lut) {
            return cachedOutput
        }

        let result = actionBlock(lut)
        cachedInput = lut
        cachedOutput = result
        return result
    }

    public func actionDetails() -> String {
        actionMetadata
            .filter { $0.key != "id" }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    public override var description: String {
        let details = actionDetails()
        return details.isEmpty ? actionName : "\(actionName): \(details)"
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = LUTAction(actionBlock: actionBlock,
                             actionName: actionName,
                             actionMetadata: actionMetadata)
        copy.cachedInput = cachedInput
        copy.cachedOutput = cachedOutput
        return copy
    }
}
