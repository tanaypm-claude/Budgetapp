import Foundation

/// Formats `Decimal` money values. Currency code is read from `AppSettings`
/// (defaults to INR) so the whole app shows one consistent symbol.
enum CurrencyFormatter {

    private static func formatter(code: String, fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = fractionDigits
        return formatter
    }

    /// Full currency string, e.g. "₹1,234.50".
    static func string(_ amount: Decimal, code: String = AppSettings.currencyCode) -> String {
        let number = NSDecimalNumber(decimal: amount)
        return formatter(code: code, fractionDigits: 2).string(from: number)
            ?? "\(AppSettings.currencySymbol)\(number.stringValue)"
    }

    /// Compact whole-number form for tight UI (no decimals), e.g. "₹1,234".
    static func compact(_ amount: Decimal, code: String = AppSettings.currencyCode) -> String {
        let number = NSDecimalNumber(decimal: amount)
        return formatter(code: code, fractionDigits: 0).string(from: number)
            ?? "\(AppSettings.currencySymbol)\(number.intValue)"
    }

    /// Signed form that prefixes +/− and uses magnitude, e.g. "−₹500.00".
    static func signed(_ amount: Decimal, type: TransactionType, code: String = AppSettings.currencyCode) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let base = string(magnitude, code: code)
        switch type {
        case .income: return "+\(base)"
        case .expense: return "−\(base)"
        case .transfer: return base
        }
    }
}
