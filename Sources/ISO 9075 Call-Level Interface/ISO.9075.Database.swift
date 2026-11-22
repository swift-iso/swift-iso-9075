extension ISO.`9075` {
    public protocol Reader: Sendable {
        associatedtype Connection: ISO.`9075`.Connection

        @_disfavoredOverload
        func read<Value: Sendable, Thrown: Swift::Error>(
            _ body: @Sendable (Connection) throws(Thrown) -> Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> Value
    }

    public protocol Database: Reader {
        @_disfavoredOverload
        func write<Value: Sendable, Thrown: Swift::Error>(
            _ body: @Sendable (Connection) throws(Thrown) -> Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> Value

        @_disfavoredOverload
        func withRollback<Value: Sendable, Thrown: Swift::Error>(
            _ body: @Sendable (Connection) throws(Thrown) -> Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> Value
    }
}

extension ISO.`9075`.Reader {
    public func read<Value: Sendable>(
        _ body: @Sendable (Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await reading(self, body)
        } catch {
            throw error.error
        }
    }
}

extension ISO.`9075`.Database {
    public func write<Value: Sendable>(
        _ body: @Sendable (Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await writing(self, body)
        } catch {
            throw error.error
        }
    }

    public func withRollback<Value: Sendable>(
        _ body: @Sendable (Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await rollingBack(self, body)
        } catch {
            throw error.error
        }
    }

    public func execute(_ fragment: ISO.`9075`.Fragment) async throws(ISO.`9075`.Error) -> Int {
        try await write { connection throws(ISO.`9075`.Error) in try connection.execute(fragment) }
    }
}

private func reading<Reader: ISO.`9075`.Reader, Value: Sendable, Thrown: Swift::Error>(
    _ reader: Reader,
    _ body: @Sendable (Reader.Connection) throws(Thrown) -> Value
) async throws(ISO.`9075`.Failure<Thrown>) -> Value {
    try await reader.read(body)
}

private func writing<Database: ISO.`9075`.Database, Value: Sendable, Thrown: Swift::Error>(
    _ database: Database,
    _ body: @Sendable (Database.Connection) throws(Thrown) -> Value
) async throws(ISO.`9075`.Failure<Thrown>) -> Value {
    try await database.write(body)
}

private func rollingBack<Database: ISO.`9075`.Database, Value: Sendable, Thrown: Swift::Error>(
    _ database: Database,
    _ body: @Sendable (Database.Connection) throws(Thrown) -> Value
) async throws(ISO.`9075`.Failure<Thrown>) -> Value {
    try await database.withRollback(body)
}
