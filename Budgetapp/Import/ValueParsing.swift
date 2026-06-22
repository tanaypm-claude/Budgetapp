import Foundation

/// Shared helpers for turning messy statement strings into typed values.
/// Used by both the CSV and PDF importers, so it lives on its own and is
/// directly unit tested.
enum ValueParsing {

    // MARK: Amounts

    /// Parse a monetary string into a `Decimal`, tolerating currency symbols,
    /// thousands separators, parentheses for negatives, and trailing `CR`/`DR`.
    /// Returns `nil` when no numeric content is present.
    static func parseAmount(_ raw: String) -> Decimal? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        var isNegative = false

        // Parentheses denote negative, e.g. "(1,200.00)".
        if s.hasPrefix("(") && s.hasSuffix(")") {
            isNegative = true
            s.removeFirst()
            s.removeLast()
        }

        // Trailing / leading credit-debit markers.
        let upper = s.uppercased()
        if upper.hasSuffix("CR") || upper.hasPrefix("CR") {
            s = stripMarker(s, "CR")
        } else if upper.hasSuffix("DR") || upper.hasPrefix("DR") {
            s = stripMarker(s, "DR")
            isNegative = true
        }

        if s.contains("-") { isNegative = true }

        // Keep only digits and separators.
        let allowed = Set("0123456789.,")
        var filtered = String(s.unicodeScalars.filter { allowed.contains(Character($0)) })
        guard !filtered.isEmpty else { return nil }

        filtered = normalizeSeparators(filtered)

        guard let value = Decimal(string: filtered) else { return nil }
        return isNegative ? -value : value
    }

    private static func stripMarker(_ s: String, _ marker: String) -> String {
        var result = s
        if result.uppercased().hasSuffix(marker) {
            result = String(result.dropLast(marker.count))
        }
        if result.uppercased().hasPrefix(marker) {
            result = String(result.dropFirst(marker.count))
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Decide whether `,` or `.` is the decimal separator and produce a string
    /// `Decimal(string:)` accepts (period decimal, no grouping).
    private static func normalizeSeparators(_ input: String) -> String {
        let hasComma = input.contains(",")
        let hasDot = input.contains(".")

        if hasComma && hasDot {
            // Whichever appears last is the decimal separator.
            if input.lastIndex(of: ",")! > input.lastIndex(of: ".")! {
                // European style: 1.234,56
                return input.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                // US/Indian style: 1,234.56
                return input.replacingOccurrences(of: ",", with: "")
            }
        }

        if hasComma {
            // Ambiguous single comma. Treat as decimal only when it looks like
            // exactly two trailing digits (e.g. "12,50"); otherwise grouping.
            let parts = input.split(separator: ",")
            if parts.count == 2 && parts[1].count == 2 {
                return input.replacingOccurrences(of: ",", with: ".")
            }
            return input.replacingOccurrences(of: ",", with: "")
        }

        return input
    }

    // MARK: Dates

    /// Common statement date formats, tried in order.
    static let dateFormats: [String] = [
        "yyyy-MM-dd",
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "MM/dd/yyyy",
        "dd/MM/yy",
        "dd-MM-yy",
        "dd MMM yyyy",
        "dd-MMM-yyyy",
        "dd MMM yy",
        "dd-MMM-yy",
        "MMM dd, yyyy",
        "yyyy/MM/dd",
        "dd.MM.yyyy"
    ]

    private static let referenceFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Parse a date string against the known statement formats.
    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for format in dateFormats {
            referenceFormatter.dateFormat = format
            if let date = referenceFormatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}
