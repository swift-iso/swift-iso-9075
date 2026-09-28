extension ISO_9075 {
    public protocol Dialect: Sendable {
        func placeholder(_ offset: Int) -> String
        func literal(_ value: Value) throws(Value.Failure) -> String
        var notDistinct: String { get }
        var distinct: String { get }
        var defaultPrimaryKey: String { get }
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
    public var notDistinct: String { "IS NOT DISTINCT FROM" }

    public var distinct: String { "IS DISTINCT FROM" }

    public var defaultPrimaryKey: String { "DEFAULT" }

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
            }
        }
        return sql
    }
}
