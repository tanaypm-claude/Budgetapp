import Foundation

/// A merchant the user appears to pay on a regular cadence, surfaced as a
/// suggestion to create a `RecurringPayment`.
struct RecurringCandidate: Identifiable {
    let id = UUID()
    var merchantKey: String
    var displayName: String
    var typicalAmount: Decimal
    var frequency: RecurringFrequency
    var occurrences: Int
    var lastDate: Date
    var suggestedNextDate: Date
    var categoryId: UUID?
}

enum RecurringDetector {

    /// Find likely recurring expenses from transaction history. Groups by a
    /// normalized merchant key, then accepts groups with enough occurrences at a
    /// roughly regular cadence.
    static func detect<T: BudgetTransactionConvertible & MerchantNaming>(
        transactions: [T],
        minimumOccurrences: Int = 3,
        calendar: Calendar = .current
    ) -> [RecurringCandidate] {
        let expenses = transactions.filter { $0.type == .expense }
        var groups: [String: [T]] = [:]
        for txn in expenses {
            let key = TransactionSignature.normalize(txn.merchantName)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(txn)
        }

        var candidates: [RecurringCandidate] = []
        for (key, items) in groups where items.count >= minimumOccurrences {
            let sorted = items.sorted { $0.date < $1.date }
            let gaps = zip(sorted.dropFirst(), sorted).map { later, earlier in
                calendar.dateComponents([.day], from: earlier.date, to: later.date).day ?? 0
            }
            guard let medianGap = median(gaps), medianGap > 0 else { continue }
            guard let frequency = frequency(forDayGap: medianGap) else { continue }

            let amounts = sorted.map { magnitude($0.amount) }
            let typical = median(amounts) ?? amounts.first ?? 0
            let last = sorted.last!.date

            candidates.append(
                RecurringCandidate(
                    merchantKey: key,
                    displayName: sorted.last!.merchantName,
                    typicalAmount: typical,
                    frequency: frequency,
                    occurrences: sorted.count,
                    lastDate: last,
                    suggestedNextDate: frequency.nextDate(after: last, calendar: calendar),
                    categoryId: sorted.last!.categoryId
                )
            )
        }
        return candidates.sorted { $0.occurrences > $1.occurrences }
    }

    static func frequency(forDayGap gap: Int) -> RecurringFrequency? {
        switch gap {
        case 5...10: return .weekly
        case 11...18: return .biweekly
        case 25...35: return .monthly
        case 80...100: return .quarterly
        case 350...380: return .yearly
        default: return nil
        }
    }

    // MARK: Median helpers

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func median(_ values: [Decimal]) -> Decimal? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted(by: <)
        return sorted[sorted.count / 2]
    }

    private static func magnitude(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}

/// Lets the detector read a merchant label off either the model or a fixture.
protocol MerchantNaming {
    var merchantName: String { get }
}

extension Transaction: MerchantNaming {
    var merchantName: String { merchant.isEmpty ? narration : merchant }
}
