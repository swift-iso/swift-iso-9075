extension ISO_9075 {
    public enum Error: Swift::Error, Hashable, Sendable {
        case connection(String)
        case execution(String)
        case decoding(String)
        case transaction(String)
        case binding(Value.Failure)
        case diagnostic(Diagnostic)
    }
}

extension ISO_9075.Error {
    public var state: ISO_9075.Diagnostic.State? {
        guard case .diagnostic(let diagnostic) = self else { return nil }
        return diagnostic.state
    }
}
