import Foundation

/// Aggregations for the Reports screen. Pure functions over transactions so the
/// numbers are testable and the views stay thin.
enum ReportsCalculator {

    struct CategoryTotal: Identifiable {
        let categoryId: UUID?
        let amount: Decimal
        var id: String { categoryId?.uuidString ?? "uncategorised" }
    }

    struct MonthFlow: Identifiable {
        let month: Date
        let income: Decimal
        let expense: Decimal
        var id: Date { month }
        var net: Decimal { income - expense }
    }

    /// Expense totals per category for the reference month, descending.
    static func categorySpending<T: BudgetTransactionConvertible>(
        month reference: Date,
        transactions: [T],
        calendar: Calendar = .current
    ) -> [CategoryTotal] {
        var totals: [UUID?: Decimal] = [:]
        for txn in transactions where txn.type == .expense
            && calendar.isDate(txn.date, equalTo: reference, toGranularity: .month) {
            totals[txn.categoryId, default: 0] += magnitude(txn.amount)
        }
        return totals.map { CategoryTotal(categoryId: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    /// Income vs expense for the last `months` calendar months (oldest first).
    static func monthlyFlows<T: BudgetTransactionConvertible>(
        months: Int,
        endingAt reference: Date = .now,
        transactions: [T],
        calendar: Calendar = .current
    ) -> [MonthFlow] {
        (0..<months).reversed().compactMap { offset -> MonthFlow? in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: reference) else { return nil }
            let income = transactions.filter {
                $0.type == .income && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }.reduce(Decimal(0)) { $0 + magnitude($1.amount) }
            let expense = transactions.filter {
                $0.type == .expense && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }.reduce(Decimal(0)) { $0 + magnitude($1.amount) }
            return MonthFlow(month: month.startOfMonth(calendar: calendar), income: income, expense: expense)
        }
    }

    /// Monthly expense totals for a single category over the last `months`.
    static func categoryTrend<T: BudgetTransactionConvertible>(
        categoryId: UUID,
        months: Int,
        endingAt reference: Date = .now,
        transactions: [T],
        calendar: Calendar = .current
    ) -> [MonthFlow] {
        (0..<months).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: reference) else { return nil }
            let expense = transactions.filter {
                $0.type == .expense && $0.categoryId == categoryId
                    && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }.reduce(Decimal(0)) { $0 + magnitude($1.amount) }
            return MonthFlow(month: month.startOfMonth(calendar: calendar), income: 0, expense: expense)
        }
    }

    /// Unusual = an expense markedly larger than the typical (median) spend for
    /// its own category. Needs at least `minSamples` in the category to judge.
    static func unusualTransactions(
        transactions: [Transaction],
        sinceDays: Int = 90,
        multiple: Double = 2.5,
        minSamples: Int = 4,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Transaction] {
        guard let cutoff = calendar.date(byAdding: .day, value: -sinceDays, to: now) else { return [] }
        let recent = transactions.filter { $0.type == .expense && $0.date >= cutoff }

        var byCategory: [UUID?: [Decimal]] = [:]
        for txn in recent { byCategory[txn.categoryId, default: []].append(magnitude(txn.amount)) }

        var unusual: [Transaction] = []
        for txn in recent {
            let peers = byCategory[txn.categoryId] ?? []
            guard peers.count >= minSamples, let med = median(peers), med > 0 else { continue }
            let threshold = med * Decimal(multiple)
            if magnitude(txn.amount) > threshold { unusual.append(txn) }
        }
        return unusual.sorted { magnitude($0.amount) > magnitude($1.amount) }
    }

    // MARK: Helpers

    private static func median(_ values: [Decimal]) -> Decimal? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted(by: <)
        return sorted[sorted.count / 2]
    }

    private static func magnitude(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}
