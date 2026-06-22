import Foundation

/// Minimal surface a calculator needs from a transaction. Both the SwiftData
/// `Transaction` model and lightweight test fixtures conform, so all budget math
/// is unit tested without a store.
protocol BudgetTransactionConvertible {
    var date: Date { get }
    var amount: Decimal { get }
    var type: TransactionType { get }
    var categoryId: UUID? { get }
    var accountId: UUID? { get }
}

extension Transaction: BudgetTransactionConvertible {}

// MARK: - Summary value types

struct CategorySpendSummary: Identifiable {
    let categoryId: UUID
    var spent: Decimal
    var budget: Decimal

    var id: UUID { categoryId }
    var remaining: Decimal { budget - spent }
    var isOverBudget: Bool { budget > 0 && spent > budget }
    /// Fraction in 0...∞ (can exceed 1 when overspent). 0 when no budget set.
    var fractionUsed: Double {
        guard budget > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent).doubleValue
            / NSDecimalNumber(decimal: budget).doubleValue
    }
    /// True when spend is within 15% of (or over) the budget.
    var isNearLimit: Bool { budget > 0 && fractionUsed >= 0.85 }
}

struct MonthlyOverview {
    var totalBudget: Decimal
    var totalSpent: Decimal
    var totalIncome: Decimal
    var daysLeftInMonth: Int
    var daysInMonth: Int

    var remainingBudget: Decimal { totalBudget - totalSpent }

    /// Even daily pace for the remaining budget across remaining days.
    var safeToSpendPerDay: Decimal {
        guard daysLeftInMonth > 0 else { return remainingBudget }
        let remaining = remainingBudget
        guard remaining > 0 else { return 0 }
        return remaining / Decimal(daysLeftInMonth)
    }

    var fractionSpent: Double {
        guard totalBudget > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalSpent).doubleValue
            / NSDecimalNumber(decimal: totalBudget).doubleValue
    }
}

// MARK: - Calculator

enum BudgetCalculator {

    /// Is `date` within the calendar month containing `reference`?
    static func isSameMonth(_ date: Date, as reference: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: reference, toGranularity: .month)
    }

    /// Total expense spend for a category in the reference month.
    static func spent<T: BudgetTransactionConvertible>(
        categoryId: UUID,
        month reference: Date,
        transactions: [T],
        calendar: Calendar = .current
    ) -> Decimal {
        transactions.reduce(into: Decimal(0)) { sum, txn in
            guard txn.type == .expense,
                  txn.categoryId == categoryId,
                  isSameMonth(txn.date, as: reference, calendar: calendar) else { return }
            sum += magnitude(txn.amount)
        }
    }

    /// Total expense spend across all categories in the reference month.
    static func totalSpent<T: BudgetTransactionConvertible>(
        month reference: Date,
        transactions: [T],
        calendar: Calendar = .current
    ) -> Decimal {
        transactions.reduce(into: Decimal(0)) { sum, txn in
            guard txn.type == .expense,
                  isSameMonth(txn.date, as: reference, calendar: calendar) else { return }
            sum += magnitude(txn.amount)
        }
    }

    /// Total income in the reference month.
    static func totalIncome<T: BudgetTransactionConvertible>(
        month reference: Date,
        transactions: [T],
        calendar: Calendar = .current
    ) -> Decimal {
        transactions.reduce(into: Decimal(0)) { sum, txn in
            guard txn.type == .income,
                  isSameMonth(txn.date, as: reference, calendar: calendar) else { return }
            sum += magnitude(txn.amount)
        }
    }

    /// Live balance for an account: opening balance + signed effect of every
    /// transaction assigned to it.
    static func balance<T: BudgetTransactionConvertible>(
        accountId: UUID,
        openingBalance: Decimal,
        transactions: [T]
    ) -> Decimal {
        transactions.reduce(into: openingBalance) { running, txn in
            guard txn.accountId == accountId else { return }
            running += magnitude(txn.amount) * txn.type.balanceSign
        }
    }

    /// Per-category spend summaries for the reference month.
    static func categorySummaries<T: BudgetTransactionConvertible>(
        categories: [(id: UUID, budget: Decimal)],
        month reference: Date,
        transactions: [T],
        calendar: Calendar = .current
    ) -> [CategorySpendSummary] {
        categories.map { category in
            CategorySpendSummary(
                categoryId: category.id,
                spent: spent(categoryId: category.id, month: reference, transactions: transactions, calendar: calendar),
                budget: category.budget
            )
        }
    }

    /// Whole-month overview used by the Home screen.
    static func monthlyOverview<T: BudgetTransactionConvertible>(
        totalBudget: Decimal,
        month reference: Date,
        transactions: [T],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MonthlyOverview {
        let spent = totalSpent(month: reference, transactions: transactions, calendar: calendar)
        let income = totalIncome(month: reference, transactions: transactions, calendar: calendar)
        return MonthlyOverview(
            totalBudget: totalBudget,
            totalSpent: spent,
            totalIncome: income,
            daysLeftInMonth: daysLeftInMonth(from: now, calendar: calendar),
            daysInMonth: daysInMonth(for: reference, calendar: calendar)
        )
    }

    // MARK: Calendar helpers

    static func daysInMonth(for date: Date, calendar: Calendar = .current) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// Days remaining in the month *including today* (so today still counts as a
    /// spending day). Minimum of 1.
    static func daysLeftInMonth(from date: Date, calendar: Calendar = .current) -> Int {
        let total = daysInMonth(for: date, calendar: calendar)
        let today = calendar.component(.day, from: date)
        return max(1, total - today + 1)
    }

    private static func magnitude(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}
