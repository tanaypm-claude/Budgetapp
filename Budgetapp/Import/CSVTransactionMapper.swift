import Foundation

/// Converts a `CSVTable` plus a confirmed `ColumnMapping` into
/// `ParsedTransaction` values, normalizing debit/credit columns into
/// expense/income. Pure and fully unit tested.
enum CSVTransactionMapper {

    static func map(table: CSVTable, mapping: ColumnMapping) -> [ParsedTransaction] {
        table.rows.compactMap { row in
            mapRow(table.dictionary(for: row), mapping: mapping)
        }
    }

    static func mapRow(_ values: [String: String], mapping: ColumnMapping) -> ParsedTransaction? {
        func value(_ role: CSVColumnRole) -> String {
            guard let header = mapping.header(for: role) else { return "" }
            return (values[header] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let dateString = value(.date)
        let merchant = value(.merchant)
        let description = value(.description)
        let accountName = value(.account)
        let categoryName = value(.category)

        var issues: [String] = []

        // Resolve amount + type from the available columns.
        let resolution = resolveAmount(
            amount: value(.amount),
            debit: value(.debit),
            credit: value(.credit)
        )

        guard let amount = resolution.amount else {
            // A row with no parseable amount is not a transaction (e.g. a
            // summary/footer line); skip it silently.
            return nil
        }

        let date = ValueParsing.parseDate(dateString)
        if date == nil { issues.append("Unrecognised date") }

        let hasName = !merchant.isEmpty || !description.isEmpty
        if !hasName { issues.append("Missing merchant/description") }

        return ParsedTransaction(
            date: date,
            merchant: merchant,
            narration: description,
            amount: amount,
            type: resolution.type,
            accountName: accountName.isEmpty ? nil : accountName,
            categoryName: categoryName.isEmpty ? nil : categoryName,
            needsReview: !issues.isEmpty,
            issues: issues
        )
    }

    struct AmountResolution {
        var amount: Decimal?
        var type: TransactionType
    }

    /// Normalize the various amount representations into a positive magnitude
    /// plus a transaction type.
    static func resolveAmount(amount: String, debit: String, credit: String) -> AmountResolution {
        let debitValue = ValueParsing.parseAmount(debit)
        let creditValue = ValueParsing.parseAmount(credit)

        // Separate debit / credit columns take precedence when present.
        if debitValue != nil || creditValue != nil {
            if let d = debitValue, d != 0 {
                return AmountResolution(amount: abs(d), type: .expense)
            }
            if let c = creditValue, c != 0 {
                return AmountResolution(amount: abs(c), type: .income)
            }
            // Both zero/blank → no transaction.
            return AmountResolution(amount: nil, type: .expense)
        }

        // Single signed amount column.
        if let value = ValueParsing.parseAmount(amount) {
            if value < 0 {
                return AmountResolution(amount: -value, type: .expense)
            } else {
                return AmountResolution(amount: value, type: .income)
            }
        }

        return AmountResolution(amount: nil, type: .expense)
    }

    private static func abs(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}
