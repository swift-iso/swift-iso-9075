extension ISO_9075 {
    public protocol Connection: Sendable {
        associatedtype Dialect: ISO_9075.Dialect
        associatedtype Row: ISO_9075.Row

        var dialect: Dialect { get }

        func execute(_ statement: Rendering) async throws(ISO_9075.Error) -> Int

        func fetchAll<Value: Sendable>(
            _ statement: Rendering,
            decode: (Row) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> [Value]
    }
}

extension ISO_9075.Connection {
    public func execute(_ fragment: ISO_9075.Fragment) async throws(ISO_9075.Error) -> Int {
        try await execute(dialect.render(fragment))
    }

    public func fetchAll<Value: Sendable>(
        _ fragment: ISO_9075.Fragment,
        decode: (Row) throws(ISO_9075.Error) -> Value
    ) async throws(ISO_9075.Error) -> [Value] {
        try await fetchAll(dialect.render(fragment), decode: decode)
    }

    public func fetchOne<Value: Sendable>(
        _ fragment: ISO_9075.Fragment,
        decode: (Row) throws(ISO_9075.Error) -> Value
    ) async throws(ISO_9075.Error) -> Value? {
        try await fetchAll(fragment, decode: decode).first
    }
}
