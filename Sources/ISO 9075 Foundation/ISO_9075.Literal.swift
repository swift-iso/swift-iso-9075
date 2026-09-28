public import Byte
internal import ISO_8601
public import Time

extension ISO_9075 {
    public enum Literal {
        public static func character(_ text: String) -> String {
            "'" + text.replacing("'", with: "''") + "'"
        }

        public static func binary(_ bytes: [Byte]) -> String {
            "X'" + bytes.map { byte in
                let hex = String(byte.underlying, radix: 16, uppercase: true)
                return hex.count == 1 ? "0" + hex : hex
            }.joined() + "'"
        }

        public static func timestamp(_ instant: Instant) throws(Value.Failure) -> String {
            let dateTime: ISO_8601.DateTime
            do throws(ISO_8601.DateTime.Error) {
                dateTime = try ISO_8601.DateTime(
                    Time.Instant(offset: .seconds(instant.secondsSinceUnixEpoch) + .nanoseconds(instant.nanosecondFraction))
                )
            } catch {
                throw Value.Failure(error)
            }
            return padded(dateTime.date.year, 4) + "-" + padded(dateTime.date.month, 2) + "-"
                + padded(dateTime.date.day, 2) + " " + padded(dateTime.hour, 2) + ":"
                + padded(dateTime.minute, 2) + ":" + padded(dateTime.second, 2) + "."
                + padded(dateTime.nanoseconds / 1_000_000, 3)
        }

        public static func instant(_ text: some StringProtocol) throws(Value.Failure) -> Instant {
            let fields = text.split(whereSeparator: { " T-:.".contains($0) }).map { Int($0) }
            guard fields.count >= 6, fields.allSatisfy({ $0 != nil }) else {
                throw Value.Failure("\(text) is not a timestamp")
            }
            let values = fields.compactMap(\.self)
            let days: Int
            do throws(ISO_8601.CalendarDate.Error) {
                days = try ISO_8601.CalendarDate(year: values[0], month: values[1], day: values[2]).daysSinceUnixEpoch
            } catch {
                throw Value.Failure(error)
            }
            let fraction = fields.count > 6 ? text.split(separator: ".").last.map { String($0.prefix(9)) } ?? "" : ""
            return Instant(
                _unchecked: (),
                secondsSinceUnixEpoch: Int64(days) * 86_400 + Int64(values[3] * 3_600 + values[4] * 60 + values[5]),
                nanosecondFraction: Int32((fraction + String(repeating: "0", count: 9 - fraction.count))) ?? 0
            )
        }

        private static func padded(_ value: some BinaryInteger, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
    }
}
