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
