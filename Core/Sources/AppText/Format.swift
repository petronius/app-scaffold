import Foundation

/// The one set of functions that turn figures into text.
///
/// Every shown number goes through here. Rounding uses the standard library's
/// `rounded()`, which rounds a half away from zero, so 102.5 reads 103.
/// `String(format:)` with a float specifier (which rounds a half to even),
/// number format styles and `Int(value)` on a shown figure (which cuts the
/// fraction off) are not used anywhere in the app; `FormattingSourceScanTests`
/// checks the sources. Add a function here when a kind of figure is missing.
public enum Format {

    /// The minus sign U+2212, used for every negative figure.
    public static let minus = "\u{2212}"

    /// The space that groups digits: U+202F NARROW NO-BREAK SPACE. A line
    /// never breaks at it, so a grouped figure stays on one line.
    public static let groupSeparator = "\u{202F}"

    /// The mark in place of a figure that cannot be worked out.
    public static var noValue: String { Copy.figure.noValue }

    // MARK: Plain figures

    /// A number with a fixed count of decimals, rounded half away from zero,
    /// with a true minus sign. `plusSign` prefixes "+" to positive values.
    public static func number(_ value: Double, decimals: Int, plusSign: Bool = false) -> String {
        guard value.isFinite else { return noValue }
        let scale = pow(10.0, Double(max(decimals, 0)))
        let scaled = (abs(value) * scale).rounded()
        let negative = value < 0 && scaled != 0
        let integerPart = (scaled / scale).rounded(.towardZero)
        var text = digits(integerPart)
        if decimals > 0 {
            let fraction = scaled - integerPart * scale
            text += "." + padded(fraction, width: decimals)
        }
        if negative { return minus + text }
        if plusSign && scaled != 0 { return "+" + text }
        return text
    }

    /// A whole number, ungrouped: "2026".
    public static func integer(_ value: Double) -> String { number(value, decimals: 0) }

    /// A whole number of five digits or more grouped in threes by
    /// `groupSeparator`, for a count read in prose: "15 000"; four digits
    /// stay ungrouped ("2026").
    public static func grouped(_ value: Double) -> String {
        let text = number(value, decimals: 0)
        let sign = text.hasPrefix(minus) ? minus : ""
        let body = Array(text.dropFirst(sign.count))
        guard body.count > 4, body.allSatisfy(\.isNumber) else { return text }
        var out = ""
        for (i, digit) in body.enumerated() {
            if i > 0 && (body.count - i) % 3 == 0 { out += groupSeparator }
            out.append(digit)
        }
        return sign + out
    }

    /// A count of things: "1 item", "3 items". The two forms come from the
    /// copy table, so the words stay there.
    public static func count(_ value: Int, one: String, other: (String) -> String) -> String {
        value == 1 ? one : other(grouped(Double(value)))
    }

    /// A fraction as a percentage: "87%".
    public static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return noValue }
        return number(fraction * 100, decimals: 0) + "%"
    }

    // MARK: Dates and times

    /// A calendar day in the user's locale and time zone: "9 Nov 2026".
    public static func day(_ date: Date, in zone: TimeZone = .current) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.timeZone = zone
        return date.formatted(style)
    }

    /// A time of day in the user's locale and time zone: "14:05".
    public static func time(_ date: Date, in zone: TimeZone = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return date.formatted(style)
    }

    /// A day and a time: "9 Nov 2026, 14:05".
    public static func dayAndTime(_ date: Date, in zone: TimeZone = .current) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        style.timeZone = zone
        return date.formatted(style)
    }

    // MARK: Helpers

    private static func digits(_ whole: Double) -> String {
        // Exact for every integer a Double holds below 2^53.
        guard whole < 9.0e15 else { return String(describing: whole) }
        return String(Int64(whole))
    }

    private static func padded(_ fraction: Double, width: Int) -> String {
        let text = String(Int64(fraction.rounded()))
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}
