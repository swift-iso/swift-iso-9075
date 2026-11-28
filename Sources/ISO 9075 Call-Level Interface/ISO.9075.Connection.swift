extension ISO.`9075` {
    /// What a body is lent: one connection, for the length of one scope.
    ///
    /// A conformer may be neither copyable nor escapable, and an engine's own handle should be neither: then the body
    /// cannot keep the connection past its scope. The protocol permits that and does not require it.
    public protocol Connection: ~Copyable, ~Escapable {
        associatedtype Dialect: ISO.`9075`.Dialect
        associatedtype Row: ISO.`9075`.Row & ~Escapable

        var dialect: Dialect { get }

        func execute(_ statement: Rendering) throws(ISO.`9075`.Error) -> Int

        func fetchAll<Value>(
            _ statement: Rendering,
            decode: (Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value]
    }
}

extension ISO.`9075`.Connection where Self: ~Copyable, Self: ~Escapable {
    public func execute(_ fragment: ISO.`9075`.Fragment) throws(ISO.`9075`.Error) -> Int {
        try execute(rendering(fragment))
    }

    public func fetchAll<Value>(
        _ fragment: ISO.`9075`.Fragment,
        decode: (Row) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> [Value] {
        try fetchAll(rendering(fragment), decode: decode)
    }

    private func rendering(_ fragment: ISO.`9075`.Fragment) throws(ISO.`9075`.Error) -> ISO.`9075`.Rendering {
        do throws(ISO.`9075`.Value.Failure) {
            return try dialect.render(fragment)
        } catch {
            throw .binding(error)
        }
    }

    public func fetchOne<Value>(
        _ fragment: ISO.`9075`.Fragment,
        decode: (Row) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> Value? {
        try fetchAll(fragment, decode: decode).first
    }
}
