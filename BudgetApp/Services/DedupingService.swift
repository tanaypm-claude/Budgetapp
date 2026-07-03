import Foundation

enum DedupingService {
    static func fingerprint(date: Date, merchant: String, amount: Decimal, accountId: UUID?) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        let normalizedMerchant = merchant
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let roundedAmount = NSDecimalNumber(decimal: amount.absoluteValue.roundedToPaise).stringValue
        return [day, normalizedMerchant, roundedAmount, accountId?.uuidString ?? "no-account"].joined(separator: "|")
    }

    static func markDuplicates(_ drafts: [DraftTransaction], existing: [BudgetTransaction]) -> [DraftTransaction] {
        var seen = Set(existing.map(\.fingerprint))
        return drafts.map { draft in
            var copy = draft
            let key = fingerprint(
                date: draft.date,
                merchant: draft.merchant,
                amount: draft.amount,
                accountId: draft.accountId
            )
            if seen.contains(key) {
                copy.duplicateCandidate = true
                copy.isReviewed = false
            } else {
                seen.insert(key)
            }
            return copy
        }
    }

    static func likelyDuplicates(for draft: DraftTransaction, existing: [BudgetTransaction]) -> [BudgetTransaction] {
        let target = fingerprint(
            date: draft.date,
            merchant: draft.merchant,
            amount: draft.amount,
            accountId: draft.accountId
        )
        return existing.filter { $0.fingerprint == target }
    }
}
