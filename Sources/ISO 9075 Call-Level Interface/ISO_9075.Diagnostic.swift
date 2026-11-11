extension ISO_9075 {
    public struct Diagnostic: Hashable, Sendable {
        public let state: State
        public let native: Int32?
        public let message: String

        public init(state: State, native: Int32? = nil, message: String) {
            self.state = state
            self.native = native
            self.message = message
        }
    }
}

extension ISO_9075.Diagnostic: CustomStringConvertible {
    public var description: String {
        "SQLSTATE \(state)" + (native.map { " (\($0))" } ?? "") + ": \(message)"
    }
}
