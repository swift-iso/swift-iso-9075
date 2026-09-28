extension ISO_9075 {
    public enum Error: Swift.Error, Hashable, Sendable {
        case connection(String)
        case execution(String)
        case decoding(String)
        case transaction(String)
        case binding(Value.Failure)
    }
}
