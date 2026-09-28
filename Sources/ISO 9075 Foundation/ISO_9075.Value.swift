public import Byte
public import RFC_4122
public import Time

extension ISO_9075 {
    public enum Value: Hashable, Sendable {
        case null
        case bool(Bool)
        case int(Int64)
        case double(Double)
        case text(String)
        case blob([Byte])
        case timestamp(Instant)
        case uuid(RFC_4122.UUID)
        case decimal(String)
        case json([Byte])
        indirect case array([Value])
        case invalid(Failure)
    }
}

extension ISO_9075.Value {
    public struct Failure: Hashable, Sendable, Error {
        public let description: String

        public init(_ description: String) {
            self.description = description
        }

        public init(_ error: any Error) {
            self.description = String(describing: error)
        }
    }
}

extension ISO_9075.Value {
    public var literal: String {
        get throws(Failure) {
            switch self {
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
            case .array(let values): "ARRAY[" + (try values.map { value throws(Failure) in try value.literal }).joined(separator: ", ") + "]"
            case .invalid(let failure): throw failure
            }
        }
    }
}
