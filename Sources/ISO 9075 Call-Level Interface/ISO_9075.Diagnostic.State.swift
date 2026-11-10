extension ISO_9075.Diagnostic {
    public struct State: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: String

        public init?(rawValue: String) {
            guard rawValue.utf8.count == 5, rawValue.utf8.allSatisfy(Self.admits) else { return nil }
            self.rawValue = rawValue
        }

        private static func admits(_ byte: UInt8) -> Bool {
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
        }

        public var `class`: Substring { rawValue.prefix(2) }

        public var description: String { rawValue }

        private init(standard rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension ISO_9075.Diagnostic.State {
    public static let connectionException = Self(standard: "08000")
    public static let unableToEstablishConnection = Self(standard: "08001")
    public static let featureNotSupported = Self(standard: "0A000")
    public static let dataException = Self(standard: "22000")
    public static let stringDataRightTruncation = Self(standard: "22001")
    public static let numericValueOutOfRange = Self(standard: "22003")
    public static let integrityConstraintViolation = Self(standard: "23000")
    public static let restrictViolation = Self(standard: "23001")
    public static let invalidTransactionState = Self(standard: "25000")
    public static let readOnlyTransaction = Self(standard: "25006")
    public static let serializationFailure = Self(standard: "40001")
    public static let syntaxErrorOrAccessRuleViolation = Self(standard: "42000")
    public static let generalError = Self(standard: "HY000")
    public static let operationCanceled = Self(standard: "HY008")
}
