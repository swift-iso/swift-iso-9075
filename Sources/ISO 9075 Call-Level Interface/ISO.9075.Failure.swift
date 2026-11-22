extension ISO.`9075` {
    public enum Failure<Thrown: Swift::Error>: Swift::Error {
        case database(ISO.`9075`.Error)
        case body(Thrown)
    }
}

extension ISO.`9075`.Failure: Equatable where Thrown: Equatable {}

extension ISO.`9075`.Failure: Hashable where Thrown: Hashable {}

extension ISO.`9075`.Failure where Thrown == ISO.`9075`.Error {
    public var error: ISO.`9075`.Error {
        switch self {
        case .database(let error), .body(let error): error
        }
    }
}
