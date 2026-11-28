extension ISO.`9075` {
    /// One row of a result, as a connection hands it to `decode`.
    ///
    /// A conformer may be non-escapable, and an engine whose row points into its own buffers should be: then `decode`
    /// cannot keep the row past its call, and the engine need not copy a row out. The protocol permits that and does
    /// not require it: a row that owns its values may be kept. Generic code is lent the row either way.
    public protocol Row: ~Escapable {
        var columns: [String] { get }
        func value(at index: Int) throws(ISO.`9075`.Error) -> Value
    }
}

extension ISO.`9075`.Row where Self: ~Escapable {
    public func value(named column: String) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
        guard let index = columns.firstIndex(of: column) else { throw .decoding("no column named \(column)") }
        return try value(at: index)
    }
}
