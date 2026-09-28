import Byte
import Time
import ISO_9075_Foundation
import Testing

struct Positional: ISO_9075.Dialect {
    func placeholder(_ offset: Int) -> String { "?" }
}

struct Numbered: ISO_9075.Dialect {
    func placeholder(_ offset: Int) -> String { "$\(offset)" }
}

@Suite struct `Rendering a fragment` {
    let fragment: ISO_9075.Fragment = "SELECT \(quote: "title") FROM \(ISO_9075.Identifier("reminders")) WHERE \(quote: "isCompleted") = \(.bool(true)) AND \(quote: "title") <> \(.text("Taxes"))"

    @Test func `values become placeholders in order, per the dialect`() {
        #expect(Positional().render(fragment) == ISO_9075.Rendering(
            sql: #"SELECT "title" FROM "reminders" WHERE "isCompleted" = ? AND "title" <> ?"#,
            values: [.bool(true), .text("Taxes")]
        ))
        #expect(Numbered().render(fragment).sql == #"SELECT "title" FROM "reminders" WHERE "isCompleted" = $1 AND "title" <> $2"#)
    }

    @Test func `inlining writes each value as a standard literal`() throws {
        #expect(try Positional().inline(fragment) == #"SELECT "title" FROM "reminders" WHERE "isCompleted" = TRUE AND "title" <> 'Taxes'"#)
    }

    @Test func `an invalid value cannot be inlined`() {
        #expect(throws: ISO_9075.Value.Failure("unencodable")) {
            try Positional().inline("SELECT \(.invalid(ISO_9075.Value.Failure("unencodable")))")
        }
    }

    @Test func `the dialect defaults are the standard's`() {
        #expect(Numbered().defaultPrimaryKey == "DEFAULT")
    }
}

@Suite struct `Delimited identifiers and literals` {
    @Test func `a delimiter inside an identifier is doubled`() {
        #expect(ISO_9075.Identifier(#"the "best" table"#).delimited == #""the ""best"" table""#)
    }

    @Test func `a quote inside a character literal is doubled`() {
        #expect(ISO_9075.Literal.character("it's") == "'it''s'")
    }

    @Test func `a binary literal is hexadecimal`() {
        #expect(ISO_9075.Literal.binary([Byte(0x00), Byte(0xAB), Byte(0x0F)]) == "X'00AB0F'")
    }

    @Test func `fragments join with a separator`() {
        let joined = [ISO_9075.Fragment("a"), "b", "c"].joined(separator: ", ")
        #expect(Positional().render(joined).sql == "a, b, c")
    }
}

@Suite struct `Timestamp literals` {
    @Test func `the epoch is midnight, the first of January 1970`() throws {
        #expect(try ISO_9075.Literal.timestamp(Time.Instant(secondsSinceUnixEpoch: 0)) == "1970-01-01 00:00:00.000")
    }

    @Test func `a leap day keeps its milliseconds`() throws {
        #expect(try ISO_9075.Literal.timestamp(Time.Instant(secondsSinceUnixEpoch: 951_827_696, nanosecondFraction: 123_456_789)) == "2000-02-29 12:34:56.123")
    }

    @Test func `a timestamp literal reads back as its instant`() throws {
        let instant = try Time.Instant(secondsSinceUnixEpoch: 951_827_696, nanosecondFraction: 123_000_000)
        #expect(try ISO_9075.Literal.instant("2000-02-29 12:34:56.123") == instant)
        #expect(try ISO_9075.Literal.instant("2000-02-29T12:34:56.123") == instant)
        #expect(try ISO_9075.Literal.instant("1970-01-01 00:00:00") == Time.Instant(secondsSinceUnixEpoch: 0))
    }

    @Test func `text that is not a timestamp is refused`() {
        #expect(throws: ISO_9075.Value.Failure.self) { try ISO_9075.Literal.instant("yesterday") }
    }

    @Test func `an instant before the epoch counts back`() throws {
        #expect(try ISO_9075.Literal.timestamp(Time.Instant(secondsSinceUnixEpoch: -1)) == "1969-12-31 23:59:59.000")
    }
}

@Suite struct `Debug descriptions` {
    @Test func `a fragment describes itself with its values inlined`() {
        let fragment: ISO_9075.Fragment = "SELECT \(ISO_9075.Identifier("title")) WHERE \(quote: "id") = \(.int(1)) AND \(quote: "tags") = \(.array([.text("a"), .null]))"
        #expect(fragment.debugDescription == #"SELECT "title" WHERE "id" = 1 AND "tags" = ARRAY['a', NULL]"#)
    }
}

struct Engine: ISO_9075.Dialect {
    func placeholder(_ offset: Int) -> String { "?" }
    var defaultPrimaryKey: String { "NULL" }
    var jsonBooleanOpen: String { "json(CASE " }
    var jsonBooleanClose: String { " WHEN 0 THEN 'false' WHEN 1 THEN 'true' END)" }
}

@Suite struct `Keywords` {
    let fragment: ISO_9075.Fragment = "VALUES (\(ISO_9075.Keyword.defaultPrimaryKey), \(.text("Taxes")))"

    @Test func `a dialect spells each keyword when it renders`() {
        #expect(Engine().render(fragment).sql == "VALUES (NULL, ?)")
    }

    @Test func `the standard spelling is the default`() throws {
        #expect(try Positional().inline(fragment) == "VALUES (DEFAULT, 'Taxes')")
        #expect(fragment.debugDescription == "VALUES (DEFAULT, 'Taxes')")
    }
}

@Suite struct `JSON booleans` {
    let fragment: ISO_9075.Fragment = "\(ISO_9075.Keyword.jsonBooleanOpen)\(quote: "isDone")\(ISO_9075.Keyword.jsonBooleanClose)"

    @Test func `the standard passes a boolean through`() {
        #expect(fragment.debugDescription == #""isDone""#)
    }

    @Test func `a dialect without booleans converts one`() {
        #expect(Engine().render(fragment).sql == #"json(CASE "isDone" WHEN 0 THEN 'false' WHEN 1 THEN 'true' END)"#)
    }
}

