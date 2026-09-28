internal import Byte
internal import RFC_4122

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
        switch value {
        case .null: "NULL"
        case .bool(let bool): bool ? "TRUE" : "FALSE"
        case .int(let int): "\(int)"
        case .double(let double): "\(double)"
        case .decimal(let decimal): decimal
        case .text(let text): ISO_9075.Literal.character(text)
        case .blob(let bytes): ISO_9075.Literal.binary(bytes)
        case .json(let bytes): ISO_9075.Literal.character(String(decoding: bytes.map(\.underlying), as: UTF8.self))
        case .timestamp(let instant): "TIMESTAMP " + ISO_9075.Literal.character(ISO_9075.Literal.timestamp(instant))
        case .uuid(let uuid): ISO_9075.Literal.character(String(uuid).lowercased())
        case .array(let values): "ARRAY[" + (try values.map { value throws(ISO_9075.Value.Failure) in try literal(value) }).joined(separator: ", ") + "]"
        case .invalid(let failure): throw failure
        }
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
