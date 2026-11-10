import ISO_9075_Call_Level_Interface
import Testing

struct Numbered: ISO_9075.Dialect {
    func placeholder(_ offset: Int) -> String { "$\(offset)" }
}

struct Row: ISO_9075.Row {
    let columns: [String]
    let values: [ISO_9075.Value]

    func value(at index: Int) throws(ISO_9075.Error) -> ISO_9075.Value {
        guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
        return values[index]
    }
}

struct Recording: ISO_9075.Connection {
    let dialect = Numbered()
    let rows: [Row]

    func execute(_ statement: ISO_9075.Rendering) throws(ISO_9075.Error) -> Int {
        statement.values.count
    }

    func fetchAll<Value>(
        _ statement: ISO_9075.Rendering,
        decode: (Row) throws(ISO_9075.Error) -> Value
    ) throws(ISO_9075.Error) -> [Value] {
        guard statement.sql == #"SELECT "title" FROM "reminders" WHERE "isCompleted" = $1"# else {
            throw .execution(statement.sql)
        }
        return try rows.map { row throws(ISO_9075.Error) in try decode(row) }
    }
}

enum `ISO 9075 Call-Level Interface Tests` {}

extension `ISO 9075 Call-Level Interface Tests` {
    @Suite struct `A connection executes rendered fragments` {
        let connection = Recording(rows: [
            Row(columns: ["title"], values: [.text("Groceries")]),
            Row(columns: ["title"], values: [.text("Call mom")]),
        ])
        let fragment: ISO_9075.Fragment = #"SELECT "title" FROM "reminders" WHERE "isCompleted" = \#(.bool(true))"#

        @Test func `rows are fetched through the connection's dialect`() throws {
            let titles = try connection.fetchAll(fragment) { row throws(ISO_9075.Error) in try row.value(named: "title") }
            #expect(titles == [.text("Groceries"), .text("Call mom")])
        }

        @Test func `fetching one returns the first row`() throws {
            #expect(try connection.fetchOne(fragment) { row throws(ISO_9075.Error) in try row.value(at: 0) } == .text("Groceries"))
        }

        @Test func `a missing column is a decoding error`() throws {
            #expect(throws: ISO_9075.Error.decoding("no column named body")) {
                try connection.fetchAll(fragment) { row throws(ISO_9075.Error) in try row.value(named: "body") }
            }
        }

        @Test func `an invalid value is a binding error`() {
            #expect(throws: ISO_9075.Error.binding(ISO_9075.Value.Failure("unencodable"))) {
                try connection.execute("DELETE FROM \"reminders\" WHERE \"id\" = \(.invalid(ISO_9075.Value.Failure("unencodable")))")
            }
        }
    }
}

actor Journal: ISO_9075.Database {
    private(set) var committed: [String] = []

    final class Connection: ISO_9075.Connection {
        let dialect = Numbered()
        var pending: [String] = []

        func execute(_ statement: ISO_9075.Rendering) throws(ISO_9075.Error) -> Int {
            pending.append(statement.sql)
            return 1
        }

        func fetchAll<Value>(
            _ statement: ISO_9075.Rendering,
            decode: (Row) throws(ISO_9075.Error) -> Value
        ) throws(ISO_9075.Error) -> [Value] {
            try pending.map { sql throws(ISO_9075.Error) in try decode(Row(columns: ["sql"], values: [.text(sql)])) }
        }
    }

    @_disfavoredOverload
    func read<Value: Sendable, Thrown: Error>(
        _ body: @Sendable (Connection) throws(Thrown) -> Value
    ) async throws(ISO_9075.Failure<Thrown>) -> Value {
        let connection = Connection()
        connection.pending = committed
        do {
            return try body(connection)
        } catch {
            throw .body(error)
        }
    }

    @_disfavoredOverload
    func write<Value: Sendable, Thrown: Error>(
        _ body: @Sendable (Connection) throws(Thrown) -> Value
    ) async throws(ISO_9075.Failure<Thrown>) -> Value {
        let connection = Connection()
        do {
            let value = try body(connection)
            committed += connection.pending
            return value
        } catch {
            throw .body(error)
        }
    }

    @_disfavoredOverload
    func withRollback<Value: Sendable, Thrown: Error>(
        _ body: @Sendable (Connection) throws(Thrown) -> Value
    ) async throws(ISO_9075.Failure<Thrown>) -> Value {
        do {
            return try body(Connection())
        } catch {
            throw .body(error)
        }
    }
}

struct Refusal: Error, Equatable {}

extension `ISO 9075 Call-Level Interface Tests` {
    @Suite struct `A database scopes synchronous connection work` {
        @Test func `a write scope commits every statement it ran`() async throws {
            let journal = Journal()
            try await journal.write { connection throws(ISO_9075.Error) in
                _ = try connection.execute("INSERT INTO \"a\" VALUES (\(.int(1)))")
                _ = try connection.execute("INSERT INTO \"b\" VALUES (\(.int(2)))")
            }
            #expect(await journal.committed == [#"INSERT INTO "a" VALUES ($1)"#, #"INSERT INTO "b" VALUES ($1)"#])
        }

        @Test func `a failing write scope commits nothing`() async throws {
            let journal = Journal()
            await #expect(throws: ISO_9075.Error.execution("stop")) {
                try await journal.write { connection throws(ISO_9075.Error) in
                    _ = try connection.execute("DELETE FROM \"a\"")
                    throw .execution("stop")
                }
            }
            #expect(await journal.committed.isEmpty)
        }

        @Test func `a write whose body throws its own error commits nothing, and the error comes out as the body's`() async throws {
            let journal = Journal()
            await #expect(throws: ISO_9075.Failure<Refusal>.body(Refusal())) {
                try await journal.write { connection throws(Refusal) in
                    _ = try? connection.execute("DELETE FROM \"a\"")
                    throw Refusal()
                }
            }
            #expect(await journal.committed.isEmpty)
        }

        @Test func `a statement's failure inside a body that throws only the interface's error comes out as that error`() async throws {
            let journal = Journal()
            await #expect(throws: ISO_9075.Error.execution("stop")) {
                try await journal.write { _ throws(ISO_9075.Error) in throw .execution("stop") }
            }
            await #expect(throws: ISO_9075.Error.execution("stop")) {
                try await journal.read { _ throws(ISO_9075.Error) in throw .execution("stop") }
            }
            await #expect(throws: ISO_9075.Error.execution("stop")) {
                try await journal.withRollback { _ throws(ISO_9075.Error) in throw .execution("stop") }
            }
        }

        @Test func `a rollback scope leaves the database untouched`() async throws {
            let journal = Journal()
            let count = try await journal.withRollback { connection throws(ISO_9075.Error) in try connection.execute("DELETE FROM \"a\"") }
            #expect(count == 1)
            #expect(await journal.committed.isEmpty)
        }

        @Test func `a read scope sees committed statements`() async throws {
            let journal = Journal()
            _ = try await journal.execute("DELETE FROM \"a\"")
            let seen = try await journal.read { connection throws(ISO_9075.Error) in
                try connection.fetchAll("SELECT 1") { row throws(ISO_9075.Error) in try row.value(named: "sql") }
            }
            #expect(seen == [.text(#"DELETE FROM "a""#)])
        }
    }
}

@Suite struct `A diagnostic` {
    @Test func `a state is five digits or capital letters`() {
        #expect(ISO_9075.Diagnostic.State(rawValue: "23505")?.rawValue == "23505")
        #expect(ISO_9075.Diagnostic.State(rawValue: "23P01")?.rawValue == "23P01")
        #expect(ISO_9075.Diagnostic.State(rawValue: "2350") == nil)
        #expect(ISO_9075.Diagnostic.State(rawValue: "23p01") == nil)
        #expect(ISO_9075.Diagnostic.State(rawValue: "235051") == nil)
    }

    @Test func `a state's class is its first two characters`() {
        #expect(ISO_9075.Diagnostic.State(rawValue: "23505")?.class == "23")
        #expect(ISO_9075.Diagnostic.State.integrityConstraintViolation.class == "23")
    }

    @Test func `an error reports the state of its diagnostic, and no state otherwise`() {
        let diagnostic = ISO_9075.Diagnostic(state: .integrityConstraintViolation, native: 1555, message: "UNIQUE constraint failed")
        #expect(ISO_9075.Error.diagnostic(diagnostic).state == .integrityConstraintViolation)
        #expect(ISO_9075.Error.execution("no state").state == nil)
    }
}
