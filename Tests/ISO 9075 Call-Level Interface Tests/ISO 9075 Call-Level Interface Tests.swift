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

    func read<Value: Sendable>(
        _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
    ) async throws(ISO_9075.Error) -> Value {
        let connection = Connection()
        connection.pending = committed
        return try body(connection)
    }

    func write<Value: Sendable>(
        _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
    ) async throws(ISO_9075.Error) -> Value {
        let connection = Connection()
        let value = try body(connection)
        committed += connection.pending
        return value
    }

    func withRollback<Value: Sendable>(
        _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
    ) async throws(ISO_9075.Error) -> Value {
        try body(Connection())
    }
}

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
