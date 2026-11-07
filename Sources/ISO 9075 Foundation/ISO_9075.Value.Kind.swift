import Byte
import RFC_4122
import Time


extension ISO_9075.Value {
    public enum Kind: Hashable, Sendable {
        case bool
        case int
        case double
        case text
        case blob
        case timestamp
        case uuid
        case decimal
        case json
    }
}
