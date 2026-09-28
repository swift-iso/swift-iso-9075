extension ISO_9075 {
    public protocol Reader: Sendable {
        func read<Value: Sendable>(
            _ body: @Sendable (any Connection) async throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value
    }

    public protocol Database: Reader {
        func write<Value: Sendable>(
            _ body: @Sendable (any Connection) async throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value

        func withRollback<Value: Sendable>(
            _ body: @Sendable (any Connection) async throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value
    }
}

extension ISO_9075.Database {
    public func execute(_ fragment: ISO_9075.Fragment) async throws(ISO_9075.Error) -> Int {
        try await write { (connection: any ISO_9075.Connection) throws(ISO_9075.Error) -> Int in
            try await connection.execute(fragment)
        }
    }
}
