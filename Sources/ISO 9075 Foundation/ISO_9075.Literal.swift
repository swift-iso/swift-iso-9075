public import Byte
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

        public static func timestamp(_ instant: Instant) -> String {
            let seconds = instant.secondsSinceUnixEpoch
            let days = seconds.floorDivided(by: 86_400)
            let time = seconds - days * 86_400
            let era = (days + 719_468).floorDivided(by: 146_097)
            let dayOfEra = days + 719_468 - era * 146_097
            let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
            let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
            let shiftedMonth = (5 * dayOfYear + 2) / 153
            let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
            return padded(yearOfEra + era * 400 + (month <= 2 ? 1 : 0), 4) + "-" + padded(month, 2) + "-"
                + padded(dayOfYear - (153 * shiftedMonth + 2) / 5 + 1, 2) + " " + padded(time / 3_600, 2) + ":"
                + padded(time % 3_600 / 60, 2) + ":" + padded(time % 60, 2) + "."
                + padded(instant.nanosecondFraction / 1_000_000, 3)
        }

        private static func padded(_ value: some BinaryInteger, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
    }
}

extension Int64 {
    fileprivate func floorDivided(by divisor: Int64) -> Int64 {
        self / divisor - (self % divisor < 0 ? 1 : 0)
    }
}
