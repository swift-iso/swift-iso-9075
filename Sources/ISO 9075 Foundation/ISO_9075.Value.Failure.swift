public import Byte
public import RFC_4122
public import Time


extension ISO_9075.Value {
    public struct Failure: Hashable, Sendable, Swift.Error {
        public let description: String

        public init(_ description: String) {
            self.description = description
        }

        public init(_ error: some Swift.Error) {
            self.description = String(describing: error)
        }
    }
}
