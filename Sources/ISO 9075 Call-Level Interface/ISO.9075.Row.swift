extension ISO.`9075` {
    public protocol Row {
        var columns: [String] { get }
        func value(at index: Int) throws(ISO.`9075`.Error) -> Value
    }
}

extension ISO.`9075`.Row {
    public func value(named column: String) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
        guard let index = columns.firstIndex(of: column) else { throw .decoding("no column named \(column)") }
        return try value(at: index)
    }
}
