import Foundation

struct RecurringSuggestion: Identifiable {
    var id: String { merchantKey }
    let merchantKey: String
    let displayName: String
    let averageAmount: Decimal
    let count: Int
    let lastDate: Date
    let likelyFrequency: RecurringFrequency
}

enum RecurringDetector {
    static func suggestions(from transactions: [BudgetTransaction], calendar: Calendar = .current) -> [RecurringSuggestion] {
        let expenses = transactions.filter { $0.type == .expense && !$0.merchant.isEmpty }
        let grouped = Dictionary(grouping: expenses) { transaction in
            transaction.merchant
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return grouped.compactMap { key, values in
            let sorted = values.sorted { $0.date < $1.date }
            guard sorted.count >= 3, let last = sorted.last else { return nil }
            let gaps = zip(sorted.dropLast(), sorted.dropFirst()).compactMap { previous, next in
                calendar.dateComponents([.day], from: previous.date, to: next.date).day
            }
            guard !gaps.isEmpty else { return nil }
            let medianGap = median(gaps)
            let averageDeviation = gaps
                .map { abs(Double($0) - medianGap) }
                .reduce(0, +) / Double(gaps.count)
            guard averageDeviation <= max(4, medianGap * 0.25) else { return nil }

            let frequency: RecurringFrequency
            if medianGap < 10 {
                frequency = .weekly
            } else if medianGap < 21 {
                frequency = .fortnightly
            } else if medianGap < 50 {
                frequency = .monthly
            } else if medianGap < 120 {
                frequency = .quarterly
            } else {
                frequency = .yearly
            }

            let averageAmount = sorted.reduce(Decimal.zero) { $0 + $1.amount } / Decimal(sorted.count)
            return RecurringSuggestion(
                merchantKey: key,
                displayName: last.merchant,
                averageAmount: averageAmount,
                count: sorted.count,
                lastDate: last.date,
                likelyFrequency: frequency
            )
        }
        .sorted { $0.lastDate > $1.lastDate }
    }

    private static func median(_ values: [Int]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Double(sorted[middle - 1] + sorted[middle]) / 2
        }
        return Double(sorted[middle])
    }
}
