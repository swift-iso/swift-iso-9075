extension ISO_9075 {
    public struct Identifier: Hashable, Sendable {
        public var name: String
        public let key: ObjectIdentifier?

        public init(_ name: String, key: ObjectIdentifier? = nil) {
            self.name = name
            self.key = key
        }
    }
}

extension ISO_9075.Identifier {
    public var delimited: String {
        "\"" + name.replacing("\"", with: "\"\"") + "\""
    }
}
