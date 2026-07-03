import Foundation

enum MoneyFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let compactCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 1
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 3
        return formatter
    }()

    static func string(_ value: Decimal, compact: Bool = false) -> String {
        let formatter = compact ? compactCurrency : currency
        let number = NSDecimalNumber(decimal: value.roundedToPaise)
        return formatter.string(from: number) ?? "INR \(number.stringValue)"
    }

    static func string(_ value: Double, compact: Bool = false) -> String {
        string(Decimal(value), compact: compact)
    }
}

extension Decimal {
    var absoluteValue: Decimal {
        self < .zero ? self * Decimal(-1) : self
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    var roundedToPaise: Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}

enum AppDateFormatters {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
