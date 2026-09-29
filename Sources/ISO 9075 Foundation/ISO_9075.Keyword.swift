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
    }
}

extension ISO_9075.Keyword {
    public var standard: String {
        switch self {
        case .defaultPrimaryKey: "DEFAULT"
        case .unboundedLimit: "ALL"
        case .jsonBooleanOpen, .jsonBooleanClose, .roundOpen, .roundClose, .roundOperandOpen, .roundOperandClose,
            .roundPrecisionOpen, .roundPrecisionClose:
            ""
        }
    }
}
