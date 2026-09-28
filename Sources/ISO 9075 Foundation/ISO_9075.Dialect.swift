extension ISO_9075 {
    public protocol Dialect: Sendable {
        func placeholder(_ offset: Int) -> String
        func literal(_ value: Value) throws(Value.Failure) -> String
        var defaultPrimaryKey: String { get }
        var jsonBooleanOpen: String { get }
        var jsonBooleanClose: String { get }
    }

    public struct Rendering: Hashable, Sendable {
        public let sql: String
        public let values: [Value]

        public init(sql: String, values: [Value]) {
            self.sql = sql
            self.values = values
        }
    }
}

extension ISO_9075.Dialect {
    public var defaultPrimaryKey: String { ISO_9075.Keyword.defaultPrimaryKey.standard }

    public var jsonBooleanOpen: String { ISO_9075.Keyword.jsonBooleanOpen.standard }

    public var jsonBooleanClose: String { ISO_9075.Keyword.jsonBooleanClose.standard }

    public func spelling(_ keyword: ISO_9075.Keyword) -> String {
        switch keyword {
        case .defaultPrimaryKey: defaultPrimaryKey
        case .jsonBooleanOpen: jsonBooleanOpen
        case .jsonBooleanClose: jsonBooleanClose
        }
    }

    public func literal(_ value: ISO_9075.Value) throws(ISO_9075.Value.Failure) -> String {
        try value.literal
    }

    public func render(_ fragment: ISO_9075.Fragment) -> ISO_9075.Rendering {
        var sql = ""
        var values: [ISO_9075.Value] = []
        for segment in fragment.segments {
            switch segment {
            case .sql(let text):
                sql.append(text)
            case .identifier(let identifier):
                sql.append(identifier.delimited)
            case .value(let value):
                values.append(value)
                sql.append(placeholder(values.count))
            case .keyword(let keyword):
                sql.append(spelling(keyword))
            }
        }
        return ISO_9075.Rendering(sql: sql, values: values)
    }

    public func inline(_ fragment: ISO_9075.Fragment) throws(ISO_9075.Value.Failure) -> String {
        var sql = ""
        for segment in fragment.segments {
            switch segment {
            case .sql(let text): sql.append(text)
            case .identifier(let identifier): sql.append(identifier.delimited)
            case .value(let value): sql.append(try literal(value))
            case .keyword(let keyword): sql.append(spelling(keyword))
            }
        }
        return sql
    }
}
