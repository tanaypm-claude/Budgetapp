import XCTest
@testable import Budgetapp

private struct RecurringFixture: BudgetTransactionConvertible, MerchantNaming {
    var date: Date
    var amount: Decimal
    var type: TransactionType = .expense
    var categoryId: UUID? = nil
    var accountId: UUID? = nil
    var merchantName: String
}

final class RecurringDetectorTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testDetectsMonthlySubscription() {
        let txns = [
            RecurringFixture(date: day(2026, 3, 5), amount: 649, merchantName: "Netflix"),
            RecurringFixture(date: day(2026, 4, 5), amount: 649, merchantName: "Netflix"),
            RecurringFixture(date: day(2026, 5, 5), amount: 649, merchantName: "Netflix"),
            RecurringFixture(date: day(2026, 6, 5), amount: 649, merchantName: "Netflix")
        ]
        let candidates = RecurringDetector.detect(transactions: txns, calendar: calendar)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].frequency, .monthly)
        XCTAssertEqual(candidates[0].typicalAmount, Decimal(649))
        XCTAssertEqual(candidates[0].occurrences, 4)
    }

    func testIgnoresTooFewOccurrences() {
        let txns = [
            RecurringFixture(date: day(2026, 5, 5), amount: 649, merchantName: "Netflix"),
            RecurringFixture(date: day(2026, 6, 5), amount: 649, merchantName: "Netflix")
        ]
        XCTAssertTrue(RecurringDetector.detect(transactions: txns, calendar: calendar).isEmpty)
    }

    func testDetectsWeekly() {
        let txns = (0..<5).map { week in
            RecurringFixture(date: day(2026, 6, 1 + week * 7), amount: 200, merchantName: "Gym Smoothie")
        }
        let candidates = RecurringDetector.detect(transactions: txns, calendar: calendar)
        XCTAssertEqual(candidates.first?.frequency, .weekly)
    }

    func testIrregularGapsRejected() {
        let txns = [
            RecurringFixture(date: day(2026, 1, 1), amount: 100, merchantName: "Random"),
            RecurringFixture(date: day(2026, 1, 3), amount: 100, merchantName: "Random"),
            RecurringFixture(date: day(2026, 6, 20), amount: 100, merchantName: "Random")
        ]
        // Median gap is wildly irregular -> not a clean frequency.
        let candidates = RecurringDetector.detect(transactions: txns, calendar: calendar)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testSuggestsNextDateAfterLast() {
        let txns = [
            RecurringFixture(date: day(2026, 3, 5), amount: 649, merchantName: "Netflix"),
            RecurringFixture(date: day(2026, 4, 5), amount: 649, merchantName: "Netflix"),
            RecurringFixture(date: day(2026, 5, 5), amount: 649, merchantName: "Netflix")
        ]
        let candidate = RecurringDetector.detect(transactions: txns, calendar: calendar).first
        XCTAssertNotNil(candidate)
        XCTAssertGreaterThan(candidate!.suggestedNextDate, candidate!.lastDate)
    }
}
