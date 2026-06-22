import XCTest
@testable import Budgetapp

/// Lightweight stand-in for a transaction so budget math is tested without a store.
private struct TxnFixture: BudgetTransactionConvertible, MerchantNaming {
    var date: Date
    var amount: Decimal
    var type: TransactionType
    var categoryId: UUID?
    var accountId: UUID?
    var merchantName: String = ""
}

final class BudgetCalculatorTests: XCTestCase {

    private let food = UUID()
    private let travel = UUID()
    private let account = UUID()
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testCategorySpendSumsOnlyExpensesInMonth() {
        let txns = [
            TxnFixture(date: day(2026, 6, 1), amount: 450, type: .expense, categoryId: food),
            TxnFixture(date: day(2026, 6, 5), amount: 550, type: .expense, categoryId: food),
            TxnFixture(date: day(2026, 5, 30), amount: 999, type: .expense, categoryId: food), // last month
            TxnFixture(date: day(2026, 6, 7), amount: 100, type: .income, categoryId: food)     // income ignored
        ]
        let spent = BudgetCalculator.spent(categoryId: food, month: day(2026, 6, 15), transactions: txns, calendar: calendar)
        XCTAssertEqual(spent, Decimal(1000))
    }

    func testTotalSpentAcrossCategories() {
        let txns = [
            TxnFixture(date: day(2026, 6, 1), amount: 450, type: .expense, categoryId: food),
            TxnFixture(date: day(2026, 6, 2), amount: 320, type: .expense, categoryId: travel)
        ]
        let total = BudgetCalculator.totalSpent(month: day(2026, 6, 10), transactions: txns, calendar: calendar)
        XCTAssertEqual(total, Decimal(770))
    }

    func testTotalIncome() {
        let txns = [
            TxnFixture(date: day(2026, 6, 1), amount: 95000, type: .income, categoryId: nil),
            TxnFixture(date: day(2026, 6, 2), amount: 320, type: .expense, categoryId: travel)
        ]
        XCTAssertEqual(BudgetCalculator.totalIncome(month: day(2026, 6, 10), transactions: txns, calendar: calendar), Decimal(95000))
    }

    func testAccountBalanceCombinesOpeningAndTransactions() {
        let txns = [
            TxnFixture(date: day(2026, 6, 1), amount: 95000, type: .income, categoryId: nil, accountId: account),
            TxnFixture(date: day(2026, 6, 2), amount: 450, type: .expense, categoryId: food, accountId: account),
            TxnFixture(date: day(2026, 6, 3), amount: 999, type: .expense, categoryId: food, accountId: UUID()) // other account
        ]
        let balance = BudgetCalculator.balance(accountId: account, openingBalance: 1000, transactions: txns)
        XCTAssertEqual(balance, Decimal(1000 + 95000 - 450))
    }

    func testTransferDoesNotAffectBalance() {
        let txns = [TxnFixture(date: day(2026, 6, 1), amount: 5000, type: .transfer, categoryId: nil, accountId: account)]
        XCTAssertEqual(BudgetCalculator.balance(accountId: account, openingBalance: 1000, transactions: txns), Decimal(1000))
    }

    func testCategorySummaryFlags() {
        let txns = [TxnFixture(date: day(2026, 6, 1), amount: 1200, type: .expense, categoryId: food)]
        let summaries = BudgetCalculator.categorySummaries(
            categories: [(food, Decimal(1000))], month: day(2026, 6, 10), transactions: txns, calendar: calendar
        )
        XCTAssertEqual(summaries.count, 1)
        XCTAssertTrue(summaries[0].isOverBudget)
        XCTAssertEqual(summaries[0].remaining, Decimal(-200))
    }

    func testNearLimitDetection() {
        let summary = CategorySpendSummary(categoryId: food, spent: Decimal(900), budget: Decimal(1000))
        XCTAssertTrue(summary.isNearLimit)
        XCTAssertFalse(summary.isOverBudget)
    }

    func testMonthlyOverviewSafeToSpend() {
        let txns = [TxnFixture(date: day(2026, 6, 1), amount: 3000, type: .expense, categoryId: food)]
        let now = day(2026, 6, 21) // 10 days left in a 30-day June (21..30 inclusive)
        let overview = BudgetCalculator.monthlyOverview(
            totalBudget: Decimal(13000), month: day(2026, 6, 21), transactions: txns, now: now, calendar: calendar
        )
        XCTAssertEqual(overview.remainingBudget, Decimal(10000))
        XCTAssertEqual(overview.daysLeftInMonth, 10)
        XCTAssertEqual(overview.safeToSpendPerDay, Decimal(1000))
    }

    func testDaysLeftIncludesToday() {
        // June has 30 days; on the 30th, 1 day remains (today).
        XCTAssertEqual(BudgetCalculator.daysLeftInMonth(from: day(2026, 6, 30), calendar: calendar), 1)
    }

    func testNoBudgetMeansZeroFraction() {
        let summary = CategorySpendSummary(categoryId: food, spent: Decimal(500), budget: Decimal(0))
        XCTAssertEqual(summary.fractionUsed, 0)
        XCTAssertFalse(summary.isOverBudget)
    }
}
