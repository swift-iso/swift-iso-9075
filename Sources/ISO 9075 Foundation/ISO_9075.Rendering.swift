extension ISO_9075 {
    public struct Rendering: Hashable, Sendable {
        public let sql: String
        public let values: [Value]

        public init(sql: String, values: [Value]) {
            self.sql = sql
            self.values = values
        }
    }
}
