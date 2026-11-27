extension ISO.`9075` {
    public protocol Reader: Sendable {
        associatedtype Connection: ISO.`9075`.Connection & ~Copyable & ~Escapable

        @_disfavoredOverload
        nonisolated(nonsending) func read<Value, Thrown: Swift::Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value
    }

    public protocol Database: Reader {
        @_disfavoredOverload
        nonisolated(nonsending) func write<Value, Thrown: Swift::Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value

        @_disfavoredOverload
        nonisolated(nonsending) func withRollback<Value, Thrown: Swift::Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value
    }
}

extension ISO.`9075`.Reader {
    public nonisolated(nonsending) func read<Value>(
        _ body: sending (borrowing Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await reading(self, body)
        } catch {
            throw error.error
        }
    }
}

extension ISO.`9075`.Database {
    public nonisolated(nonsending) func write<Value>(
        _ body: sending (borrowing Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await writing(self, body)
        } catch {
            throw error.error
        }
    }

    public nonisolated(nonsending) func withRollback<Value>(
        _ body: sending (borrowing Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await rollingBack(self, body)
        } catch {
            throw error.error
        }
    }

    public nonisolated(nonsending) func execute(_ fragment: ISO.`9075`.Fragment) async throws(ISO.`9075`.Error) -> Int {
        try await write { (connection: borrowing Connection) throws(ISO.`9075`.Error) in try connection.execute(fragment) }
    }
}

private nonisolated(nonsending) func reading<Reader: ISO.`9075`.Reader, Value, Thrown: Swift::Error>(
    _ reader: Reader,
    _ body: sending (borrowing Reader.Connection) throws(Thrown) -> sending Value
) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
    try await reader.read(body)
}

private nonisolated(nonsending) func writing<Database: ISO.`9075`.Database, Value, Thrown: Swift::Error>(
    _ database: Database,
    _ body: sending (borrowing Database.Connection) throws(Thrown) -> sending Value
) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
    try await database.write(body)
}

private nonisolated(nonsending) func rollingBack<Database: ISO.`9075`.Database, Value, Thrown: Swift::Error>(
    _ database: Database,
    _ body: sending (borrowing Database.Connection) throws(Thrown) -> sending Value
) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
    try await database.withRollback(body)
}
