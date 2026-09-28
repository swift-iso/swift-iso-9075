extension ISO_9075 {
    public struct Fragment: Hashable, Sendable {
        public enum Segment: Hashable, Sendable {
            case sql(String)
            case value(Value)
            case identifier(Identifier)
            case keyword(Keyword)
        }

        public var segments: [Segment]

        public init() {
            self.segments = []
        }

        public init(segments: [Segment]) {
            self.segments = segments
        }

        public init(_ sql: String) {
            self.segments = [.sql(sql)]
        }

        public init(quote name: String) {
            self.segments = [.sql(Identifier(name).delimited)]
        }

        public var isEmpty: Bool {
            segments.allSatisfy { segment in
                switch segment {
                case .sql(let sql): sql.isEmpty
                case .value, .identifier, .keyword: false
                }
            }
        }

        public mutating func append(_ other: Self) {
            segments.append(contentsOf: other.segments)
        }

        public static func += (lhs: inout Self, rhs: Self) {
            lhs.append(rhs)
        }

        public static func + (lhs: Self, rhs: Self) -> Self {
            Self(segments: lhs.segments + rhs.segments)
        }
    }
}

extension [ISO_9075.Fragment] {
    public func joined(separator: ISO_9075.Fragment = ISO_9075.Fragment()) -> ISO_9075.Fragment {
        guard var joined = first else { return ISO_9075.Fragment() }
        for fragment in dropFirst() {
            joined.append(separator)
            joined.append(fragment)
        }
        return joined
    }
}

extension ISO_9075.Fragment: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(segments: stringInterpolation.flushed)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        private var segments: [ISO_9075.Fragment.Segment] = []
        private var buffer = ""

        public init(literalCapacity: Int, interpolationCount: Int) {
            segments.reserveCapacity(interpolationCount + 1)
            buffer.reserveCapacity(literalCapacity)
        }

        fileprivate var flushed: [ISO_9075.Fragment.Segment] {
            buffer.isEmpty ? segments : segments + [.sql(buffer)]
        }

        public mutating func appendLiteral(_ literal: String) {
            buffer.append(literal)
        }

        public mutating func appendSegment(_ segment: ISO_9075.Fragment.Segment) {
            switch segment {
            case .sql(let sql):
                buffer.append(sql)
            case .value, .identifier, .keyword:
                if !buffer.isEmpty {
                    segments.append(.sql(buffer))
                    buffer.removeAll(keepingCapacity: true)
                }
                segments.append(segment)
            }
        }

        public mutating func appendInterpolation(raw sql: String) {
            appendLiteral(sql)
        }

        public mutating func appendInterpolation(raw sql: some LosslessStringConvertible) {
            appendLiteral(sql.description)
        }

        public mutating func appendInterpolation(quote name: String) {
            appendLiteral(ISO_9075.Identifier(name).delimited)
        }

        public mutating func appendInterpolation(text: String) {
            appendLiteral("'" + text.replacing("'", with: "''") + "'")
        }

        public mutating func appendInterpolation(_ value: ISO_9075.Value) {
            appendSegment(.value(value))
        }

        public mutating func appendInterpolation(_ identifier: ISO_9075.Identifier) {
            appendSegment(.identifier(identifier))
        }

        public mutating func appendInterpolation(_ keyword: ISO_9075.Keyword) {
            appendSegment(.keyword(keyword))
        }

        public mutating func appendInterpolation(_ fragment: ISO_9075.Fragment) {
            for segment in fragment.segments {
                appendSegment(segment)
            }
        }
    }
}

extension ISO_9075.Fragment: CustomDebugStringConvertible {
    public var debugDescription: String {
        segments.map { segment in
            switch segment {
            case .sql(let sql): sql
            case .value(let value): (try? value.literal) ?? "<invalid: \(value)>"
            case .identifier(let identifier): identifier.delimited
            case .keyword(let keyword): keyword.standard
            }
        }
        .joined()
    }
}
