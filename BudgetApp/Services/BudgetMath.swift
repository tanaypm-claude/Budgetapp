import Foundation

struct CategorySpendRow: Identifiable {
    let id: UUID
    let category: BudgetCategory
    let spent: Decimal
    let budget: Decimal

    var remaining: Decimal { budget - spent }
    var percentUsed: Double {
        guard budget > 0 else { return spent > 0 ? 1 : 0 }
        return spent.doubleValue / budget.doubleValue
    }
    var isOverBudget: Bool { remaining < 0 }
    var isCloseToBudget: Bool { !isOverBudget && percentUsed >= 0.8 }
}

struct BudgetOverview: Hashable {
    let monthStart: Date
    let monthEnd: Date
    let monthlyBudget: Decimal
    let spent: Decimal
    let income: Decimal
    let remaining: Decimal
    let daysLeft: Int
    let safeToSpendDaily: Decimal
    let reviewCount: Int

    var percentUsed: Double {
        guard monthlyBudget > 0 else { return spent > 0 ? 1 : 0 }
        return spent.doubleValue / monthlyBudget.doubleValue
    }
}

enum BudgetMath {
    static func monthInterval(containing date: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? date
        return DateInterval(start: start, end: end)
    }

    static func isDate(_ date: Date, inside interval: DateInterval) -> Bool {
        interval.contains(date)
    }

    static func overview(
        transactions: [BudgetTransaction],
        categories: [BudgetCategory],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> BudgetOverview {
        let interval = monthInterval(containing: referenceDate, calendar: calendar)
        let monthlyBudget = categories.filter(\.isActive).reduce(Decimal.zero) { $0 + max(.zero, $1.monthlyBudget) }
        let currentMonth = transactions.filter { isDate($0.date, inside: interval) }
        let spent = currentMonth
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let income = currentMonth
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let remaining = monthlyBudget - spent
        let endOfMonth = calendar.startOfDay(for: interval.end)
        let today = calendar.startOfDay(for: referenceDate)
        let daysLeft = max(1, (calendar.dateComponents([.day], from: today, to: endOfMonth).day ?? 0) + 1)
        let safeDaily = max(.zero, remaining) / Decimal(daysLeft)

        return BudgetOverview(
            monthStart: interval.start,
            monthEnd: interval.end,
            monthlyBudget: monthlyBudget,
            spent: spent,
            income: income,
            remaining: remaining,
            daysLeft: daysLeft,
            safeToSpendDaily: safeDaily,
            reviewCount: transactions.filter { !$0.isReviewed }.count
        )
    }

    static func categoryRows(
        transactions: [BudgetTransaction],
        categories: [BudgetCategory],
        referenceDate: Date = Date()
    ) -> [CategorySpendRow] {
        let interval = monthInterval(containing: referenceDate)
        return categories
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { category in
                let spent = transactions
                    .filter { $0.type == .expense && $0.categoryId == category.id && isDate($0.date, inside: interval) }
                    .reduce(Decimal.zero) { $0 + $1.amount }
                return CategorySpendRow(id: category.id, category: category, spent: spent, budget: category.monthlyBudget)
            }
    }

    static func accountBalance(account: BudgetAccount, transactions: [BudgetTransaction]) -> Decimal {
        let movement = transactions
            .filter { $0.accountId == account.id }
            .reduce(Decimal.zero) { $0 + $1.signedAmount }
        return account.openingBalance + movement
    }

    static func monthlyNet(transactions: [BudgetTransaction], monthOffset: Int, calendar: Calendar = .current) -> (income: Decimal, expenses: Decimal) {
        let date = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let interval = monthInterval(containing: date, calendar: calendar)
        let monthTransactions = transactions.filter { isDate($0.date, inside: interval) }
        let income = monthTransactions.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let expenses = monthTransactions.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        return (income, expenses)
    }
}
