extension ISO_9075 {
    public enum Keyword: Hashable, Sendable {
        case defaultPrimaryKey
        case jsonBooleanOpen
        case jsonBooleanClose
        case unboundedLimit
        case roundOpen
        case roundClose
        case roundOperandOpen
        case roundOperandClose
        case roundPrecisionOpen
        case roundPrecisionClose
        case binaryLargeObject
    }
}

extension ISO_9075.Keyword {
    public var standard: String {
        switch self {
        case .defaultPrimaryKey: "DEFAULT"
        case .unboundedLimit: "ALL"
        case .binaryLargeObject: "BLOB"
        case .jsonBooleanOpen, .jsonBooleanClose, .roundOpen, .roundClose, .roundOperandOpen, .roundOperandClose,
            .roundPrecisionOpen, .roundPrecisionClose:
            ""
        }
    }
}
