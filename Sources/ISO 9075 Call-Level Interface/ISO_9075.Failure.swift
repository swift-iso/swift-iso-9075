extension ISO_9075 {
    public enum Failure<Thrown: Swift::Error>: Swift::Error {
        case database(ISO_9075.Error)
        case body(Thrown)
    }
}

extension ISO_9075.Failure: Equatable where Thrown: Equatable {}

extension ISO_9075.Failure: Hashable where Thrown: Hashable {}

extension ISO_9075.Failure where Thrown == ISO_9075.Error {
    public var error: ISO_9075.Error {
        switch self {
        case .database(let error), .body(let error): error
        }
    }
}
