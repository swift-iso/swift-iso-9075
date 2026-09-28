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
    let dialect: any ISO_9075.Dialect = Numbered()
    let rows: [Row]

    func execute(_ statement: ISO_9075.Rendering) async throws(ISO_9075.Error) -> Int {
        statement.values.count
    }

    func fetchAll<Value: Sendable>(
        _ statement: ISO_9075.Rendering,
        decode: (any ISO_9075.Row) throws(ISO_9075.Error) -> Value
    ) async throws(ISO_9075.Error) -> [Value] {
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

    @Test func `rows are fetched through the connection's dialect`() async throws {
        let titles = try await connection.fetchAll(fragment) { row throws(ISO_9075.Error) in try row.value(named: "title") }
        #expect(titles == [.text("Groceries"), .text("Call mom")])
    }

    @Test func `fetching one returns the first row`() async throws {
        #expect(try await connection.fetchOne(fragment) { row throws(ISO_9075.Error) in try row.value(at: 0) } == .text("Groceries"))
    }

    @Test func `a missing column is a decoding error`() async throws {
        await #expect(throws: ISO_9075.Error.decoding("no column named body")) {
            try await connection.fetchAll(fragment) { row throws(ISO_9075.Error) in try row.value(named: "body") }
        }
    }
}
