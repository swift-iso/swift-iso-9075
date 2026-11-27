import ISO_9075_Call_Level_Interface
import Testing

struct Numbered: ISO.`9075`.Dialect {
    func placeholder(_ offset: Int) -> String { "$\(offset)" }
}

struct Row: ISO.`9075`.Row {
    let columns: [String]
    let values: [ISO.`9075`.Value]

    func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
        guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
        return values[index]
    }
}

struct Recording: ISO.`9075`.Connection {
    let dialect = Numbered()
    let rows: [Row]

    func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
        statement.values.count
    }

    func fetchAll<Value>(
        _ statement: ISO.`9075`.Rendering,
        decode: (Row) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> [Value] {
        guard statement.sql == #"SELECT "title" FROM "reminders" WHERE "isCompleted" = $1"# else {
            throw .execution(statement.sql)
        }
        return try rows.map { row throws(ISO.`9075`.Error) in try decode(row) }
    }
}

enum `ISO 9075 Call-Level Interface Tests` {}

extension `ISO 9075 Call-Level Interface Tests` {
    @Suite struct `A connection executes rendered fragments` {
        let connection = Recording(rows: [
            Row(columns: ["title"], values: [.text("Groceries")]),
            Row(columns: ["title"], values: [.text("Call mom")]),
        ])
        let fragment: ISO.`9075`.Fragment = #"SELECT "title" FROM "reminders" WHERE "isCompleted" = \#(.bool(true))"#

        @Test func `rows are fetched through the connection's dialect`() throws {
            let titles = try connection.fetchAll(fragment) { row throws(ISO.`9075`.Error) in try row.value(named: "title") }
            #expect(titles == [.text("Groceries"), .text("Call mom")])
        }

        @Test func `fetching one returns the first row`() throws {
            #expect(try connection.fetchOne(fragment) { row throws(ISO.`9075`.Error) in try row.value(at: 0) } == .text("Groceries"))
        }

        @Test func `a missing column is a decoding error`() throws {
            #expect(throws: ISO.`9075`.Error.decoding("no column named body")) {
                try connection.fetchAll(fragment) { row throws(ISO.`9075`.Error) in try row.value(named: "body") }
            }
        }

        @Test func `an invalid value is a binding error`() {
            #expect(throws: ISO.`9075`.Error.binding(ISO.`9075`.Value.Failure("unencodable"))) {
                try connection.execute("DELETE FROM \"reminders\" WHERE \"id\" = \(.invalid(ISO.`9075`.Value.Failure("unencodable")))")
            }
        }
    }
}

actor Journal: ISO.`9075`.Database {
    private(set) var committed: [String] = []

    /// What one scope ran. Not Sendable: it belongs to the journal.
    final class Pending {
        var statements: [String] = []
    }

    /// The journal's connection: a view of one scope's statements that cannot outlive the scope.
    struct Connection: ISO.`9075`.Connection, ~Copyable, ~Escapable {
        let dialect = Numbered()
        let pending: Pending

        @_lifetime(borrow pending)
        init(_ pending: borrowing Pending) {
            self.pending = copy pending
        }

        func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
            pending.statements.append(statement.sql)
            return 1
        }

        func fetchAll<Value>(
            _ statement: ISO.`9075`.Rendering,
            decode: (Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value] {
            try pending.statements.map { sql throws(ISO.`9075`.Error) in try decode(Row(columns: ["sql"], values: [.text(sql)])) }
        }
    }

    enum Scope {
        case read
        case write
        case rollback
    }

    @_disfavoredOverload
    nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await run(.read, body)
    }

    @_disfavoredOverload
    nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await run(.write, body)
    }

    @_disfavoredOverload
    nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await run(.rollback, body)
    }

    /// On the journal: the body arrives by `sending` and its result leaves by `sending`.
    private func run<Value, Thrown: Swift.Error>(
        _ scope: Scope,
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        let pending = Pending()
        if case .read = scope { pending.statements = committed }
        let connection = Connection(pending)
        do throws(Thrown) {
            let value = try body(connection)
            if case .write = scope { committed += pending.statements }
            return value
        } catch {
            throw .body(error)
        }
    }
}

struct Refusal: Swift.Error, Equatable {}

extension `ISO 9075 Call-Level Interface Tests` {
    @Suite struct `A database scopes synchronous connection work` {
        @Test func `a write scope commits every statement it ran`() async throws {
            let journal = Journal()
            try await journal.write { connection throws(ISO.`9075`.Error) in
                _ = try connection.execute("INSERT INTO \"a\" VALUES (\(.int(1)))")
                _ = try connection.execute("INSERT INTO \"b\" VALUES (\(.int(2)))")
            }
            #expect(await journal.committed == [#"INSERT INTO "a" VALUES ($1)"#, #"INSERT INTO "b" VALUES ($1)"#])
        }

        @Test func `a failing write scope commits nothing`() async throws {
            let journal = Journal()
            await #expect(throws: ISO.`9075`.Error.execution("stop")) {
                try await journal.write { connection throws(ISO.`9075`.Error) in
                    _ = try connection.execute("DELETE FROM \"a\"")
                    throw .execution("stop")
                }
            }
            #expect(await journal.committed.isEmpty)
        }

        @Test func `a write whose body throws its own error commits nothing, and the error comes out as the body's`() async throws {
            let journal = Journal()
            await #expect(throws: ISO.`9075`.Failure<Refusal>.body(Refusal())) {
                try await journal.write { connection throws(Refusal) in
                    do throws(ISO.`9075`.Error) {
                        _ = try connection.execute("DELETE FROM \"a\"")
                    } catch {
                        Issue.record(error)
                    }
                    throw Refusal()
                }
            }
            #expect(await journal.committed.isEmpty)
        }

        @Test func `a statement's failure inside a body that throws only the interface's error comes out as that error`() async throws {
            let journal = Journal()
            await #expect(throws: ISO.`9075`.Error.execution("stop")) {
                try await journal.write { _ throws(ISO.`9075`.Error) in throw .execution("stop") }
            }
            await #expect(throws: ISO.`9075`.Error.execution("stop")) {
                try await journal.read { _ throws(ISO.`9075`.Error) in throw .execution("stop") }
            }
            await #expect(throws: ISO.`9075`.Error.execution("stop")) {
                try await journal.withRollback { _ throws(ISO.`9075`.Error) in throw .execution("stop") }
            }
        }

        @Test func `a rollback scope leaves the database untouched`() async throws {
            let journal = Journal()
            let count = try await journal.withRollback { connection throws(ISO.`9075`.Error) in try connection.execute("DELETE FROM \"a\"") }
            #expect(count == 1)
            #expect(await journal.committed.isEmpty)
        }

        @Test func `a read scope sees committed statements`() async throws {
            let journal = Journal()
            _ = try await journal.execute("DELETE FROM \"a\"")
            let seen = try await journal.read { connection throws(ISO.`9075`.Error) in
                try connection.fetchAll("SELECT 1") { row throws(ISO.`9075`.Error) in try row.value(named: "sql") }
            }
            #expect(seen == [.text(#"DELETE FROM "a""#)])
        }
    }
}

@Suite struct `A diagnostic` {
    @Test func `a state is five digits or capital letters`() {
        #expect(ISO.`9075`.Diagnostic.State(rawValue: "23505")?.rawValue == "23505")
        #expect(ISO.`9075`.Diagnostic.State(rawValue: "23P01")?.rawValue == "23P01")
        #expect(ISO.`9075`.Diagnostic.State(rawValue: "2350") == nil)
        #expect(ISO.`9075`.Diagnostic.State(rawValue: "23p01") == nil)
        #expect(ISO.`9075`.Diagnostic.State(rawValue: "235051") == nil)
    }

    @Test func `a state's class is its first two characters`() {
        #expect(ISO.`9075`.Diagnostic.State(rawValue: "23505")?.class == "23")
        #expect(ISO.`9075`.Diagnostic.State.integrityConstraintViolation.class == "23")
    }

    @Test func `an error reports the state of its diagnostic, and no state otherwise`() {
        let diagnostic = ISO.`9075`.Diagnostic(state: .integrityConstraintViolation, native: 1555, message: "UNIQUE constraint failed")
        #expect(ISO.`9075`.Error.diagnostic(diagnostic).state == .integrityConstraintViolation)
        #expect(ISO.`9075`.Error.execution("no state").state == nil)
    }
}

/// Neither Sendable nor a value: what a body may capture, and what it may return, under `sending`.
final class Tally {
    var count = 0
}

func statements(of database: some ISO.`9075`.Database) async throws(ISO.`9075`.Error) -> Int {
    _ = try await database.execute("DELETE FROM \"a\"")
    return try await database.read { connection throws(ISO.`9075`.Error) in
        try connection.fetchAll("SELECT 1") { _ throws(ISO.`9075`.Error) in 1 }.count
    }
}

extension `ISO 9075 Call-Level Interface Tests` {
    @Suite struct `A scope sends its body and its result` {
        @Test func `a body captures what is not Sendable and returns what is not Sendable`() async throws {
            let journal = Journal()
            let captured = Tally()
            let returned: Tally = try await journal.write { connection throws(ISO.`9075`.Error) in
                captured.count += 1
                let result = Tally()
                result.count = try connection.execute("DELETE FROM \"a\"") + captured.count
                return result
            }
            returned.count += 100
            #expect(returned.count == 102)
        }

        @Test @MainActor func `a caller on the main actor is on the main actor after the scope`() async throws {
            let journal = Journal()
            let returned: Tally = try await journal.write { connection throws(ISO.`9075`.Error) in
                let result = Tally()
                result.count = try connection.execute("DELETE FROM \"a\"")
                return result
            }
            MainActor.assertIsolated()
            #expect(returned.count == 1)
        }

        @Test func `a database is used through an opaque type, and an existential through a generic function`() async throws {
            let journal = Journal()
            #expect(try await statements(of: journal) == 1)
            let existential: any ISO.`9075`.Database = journal
            #expect(try await statements(of: existential) == 2)
        }

        @Test func `a typed throw of the body's own error keeps its type through each scope`() async {
            let journal = Journal()
            await #expect(throws: ISO.`9075`.Failure<Refusal>.body(Refusal())) {
                try await journal.read { _ throws(Refusal) in throw Refusal() }
            }
            await #expect(throws: ISO.`9075`.Failure<Refusal>.body(Refusal())) {
                try await journal.withRollback { _ throws(Refusal) in throw Refusal() }
            }
        }
    }
}
