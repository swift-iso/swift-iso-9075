extension ISO_9075 {
    public enum Keyword: Hashable, Sendable {
        case defaultPrimaryKey
        case jsonBooleanOpen
        case jsonBooleanClose
    }
}

extension ISO_9075.Keyword {
    public var standard: String {
        switch self {
        case .defaultPrimaryKey: "DEFAULT"
        case .jsonBooleanOpen, .jsonBooleanClose: ""
        }
    }
}
