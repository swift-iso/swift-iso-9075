import Byte
import RFC_4122
import Time

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
