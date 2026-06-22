import Foundation

/// Identifies likely-duplicate transactions so re-importing the same statement
/// (or overlapping date ranges) doesn't create doubles.
///
/// A signature is intentionally fuzzy: same calendar day, same magnitude (to 2
/// dp) and the same normalized merchant token. This catches re-imports while
/// tolerating cosmetic differences in narration.
struct TransactionSignature: Hashable {
    let day: Date
    let amountKey: String
    let merchantKey: String

    init(date: Date, amount: Decimal, merchant: String, calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: date)
        self.amountKey = TransactionSignature.amountKey(amount)
        self.merchantKey = TransactionSignature.normalize(merchant)
    }

    static func amountKey(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        return NSDecimalNumber(decimal: magnitude)
            .multiplying(byPowerOf10: 2)
            .rounding(accordingToBehavior: nil)
            .stringValue
    }

    static func normalize(_ merchant: String) -> String {
        let lowered = merchant.lowercased()
        let allowed = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
        return String(String.UnicodeScalarView(allowed))
            .split(separator: " ")
            .prefix(3)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

enum DeduplicationService {

    /// Mark parsed rows as duplicates when their signature already exists, either
    /// among `existing` signatures or earlier in the same batch.
    static func flagDuplicates(
        in parsed: [ParsedTransaction],
        existing: Set<TransactionSignature>,
        calendar: Calendar = .current
    ) -> [ParsedTransaction] {
        var seen = existing
        return parsed.map { row in
            var row = row
            guard let date = row.date else { return row }
            let signature = TransactionSignature(
                date: date,
                amount: row.amount,
                merchant: row.displayName,
                calendar: calendar
            )
            if seen.contains(signature) {
                row.isDuplicate = true
                row.isSelectedForImport = false
                if !row.issues.contains("Possible duplicate") {
                    row.issues.append("Possible duplicate")
                }
            } else {
                seen.insert(signature)
            }
            return row
        }
    }

    /// Build a signature set from already-persisted transactions.
    static func signatures(
        for transactions: [Transaction],
        calendar: Calendar = .current
    ) -> Set<TransactionSignature> {
        Set(transactions.map { txn in
            TransactionSignature(
                date: txn.date,
                amount: txn.amount,
                merchant: txn.merchant.isEmpty ? txn.narration : txn.merchant,
                calendar: calendar
            )
        })
    }
}
