extension ISO_9075 {
    public struct Diagnostic: Hashable, Sendable, CustomStringConvertible {
        public let state: State
        public let native: Int?
        public let message: String

        public init(state: State, native: Int? = nil, message: String) {
            self.state = state
            self.native = native
            self.message = message
        }

        public var description: String {
            "SQLSTATE \(state.rawValue)" + (native.map { " (\($0))" } ?? "") + ": \(message)"
        }
    }
}
