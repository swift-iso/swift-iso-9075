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

        private static func padded(_ value: some BinaryInteger, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
    }
}
