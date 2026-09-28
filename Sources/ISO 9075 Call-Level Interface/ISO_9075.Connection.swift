extension ISO_9075 {
    public protocol Connection {
        associatedtype Dialect: ISO_9075.Dialect
        associatedtype Row: ISO_9075.Row

        var dialect: Dialect { get }

        func execute(_ statement: Rendering) throws(ISO_9075.Error) -> Int

        func fetchAll<Value>(
            _ statement: Rendering,
            decode: (Row) throws(ISO_9075.Error) -> Value
        ) throws(ISO_9075.Error) -> [Value]
    }
}

extension ISO_9075.Connection {
    public func execute(_ fragment: ISO_9075.Fragment) throws(ISO_9075.Error) -> Int {
        try execute(dialect.render(fragment))
    }

    public func fetchAll<Value>(
        _ fragment: ISO_9075.Fragment,
        decode: (Row) throws(ISO_9075.Error) -> Value
    ) throws(ISO_9075.Error) -> [Value] {
        try fetchAll(dialect.render(fragment), decode: decode)
    }

    public func fetchOne<Value>(
        _ fragment: ISO_9075.Fragment,
        decode: (Row) throws(ISO_9075.Error) -> Value
    ) throws(ISO_9075.Error) -> Value? {
        try fetchAll(fragment, decode: decode).first
    }
}
