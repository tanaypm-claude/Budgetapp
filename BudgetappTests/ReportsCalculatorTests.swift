import XCTest
@testable import Budgetapp

private struct ReportFixture: BudgetTransactionConvertible {
    var date: Date
    var amount: Decimal
    var type: TransactionType
    var categoryId: UUID?
    var accountId: UUID? = nil
}

final class ReportsCalculatorTests: XCTestCase {

    private let food = UUID()
    private let travel = UUID()
    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testCategorySpendingSortedDescending() {
        let txns = [
            ReportFixture(date: day(2026, 6, 1), amount: 450, type: .expense, categoryId: food),
            ReportFixture(date: day(2026, 6, 2), amount: 320, type: .expense, categoryId: travel),
            ReportFixture(date: day(2026, 6, 3), amount: 550, type: .expense, categoryId: food)
        ]
        let totals = ReportsCalculator.categorySpending(month: day(2026, 6, 15), transactions: txns, calendar: calendar)
        XCTAssertEqual(totals.first?.categoryId, food)
        XCTAssertEqual(totals.first?.amount, Decimal(1000))
    }

    func testMonthlyFlowsCountsMonths() {
        let txns = [
            ReportFixture(date: day(2026, 5, 1), amount: 1000, type: .income, categoryId: nil),
            ReportFixture(date: day(2026, 6, 1), amount: 400, type: .expense, categoryId: food)
        ]
        let flows = ReportsCalculator.monthlyFlows(months: 3, endingAt: day(2026, 6, 15), transactions: txns, calendar: calendar)
        XCTAssertEqual(flows.count, 3)
        XCTAssertEqual(flows.last?.expense, Decimal(400))
    }

    func testUnusualTransactionDetection() {
        // Several normal Food charges plus one large outlier in the same category.
        var all: [Transaction] = [400, 450, 420, 480].map { amount in
            Transaction(date: .now, merchant: "Swiggy", amount: Decimal(amount), type: .expense, categoryId: food)
        }
        all.append(Transaction(date: .now, merchant: "Big Dinner", amount: Decimal(3000), type: .expense, categoryId: food))

        let unusual = ReportsCalculator.unusualTransactions(transactions: all)
        XCTAssertTrue(unusual.contains { $0.merchant == "Big Dinner" })
        XCTAssertFalse(unusual.contains { $0.merchant == "Swiggy" })
    }
}
