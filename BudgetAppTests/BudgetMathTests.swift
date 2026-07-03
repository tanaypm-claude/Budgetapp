import XCTest
@testable import BudgetApp

final class BudgetMathTests: XCTestCase {
    func testOverviewCalculatesMonthlyBudgetAndSafeSpend() {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let category = BudgetCategory(name: "Food", symbol: "fork.knife", colorHex: "#D84A2B", monthlyBudget: 30000, sortOrder: 0)
        let transaction = BudgetTransaction(
            date: referenceDate,
            merchant: "Swiggy",
            amount: 12000,
            type: .expense,
            categoryId: category.id,
            isReviewed: false
        )

        let overview = BudgetMath.overview(
            transactions: [transaction],
            categories: [category],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(overview.monthlyBudget, Decimal(30000))
        XCTAssertEqual(overview.spent, Decimal(12000))
        XCTAssertEqual(overview.remaining, Decimal(18000))
        XCTAssertEqual(overview.reviewCount, 1)
        XCTAssertGreaterThan(overview.safeToSpendDaily, Decimal.zero)
    }

    func testCategorySpendRowsTrackOverspend() {
        let category = BudgetCategory(name: "Travel", symbol: "tram.fill", colorHex: "#2A7F86", monthlyBudget: 1000, sortOrder: 0)
        let transaction = BudgetTransaction(date: Date(), merchant: "Uber", amount: 1500, type: .expense, categoryId: category.id)

        let rows = BudgetMath.categoryRows(transactions: [transaction], categories: [category])

        XCTAssertEqual(rows.first?.spent, Decimal(1500))
        XCTAssertTrue(rows.first?.isOverBudget == true)
    }
}

final class AppTabTests: XCTestCase {
    func testDockCustomizationOffersStandaloneWindowsAndDecodesLegacyImportTab() {
        XCTAssertTrue(AppTab.allCases.contains(.reports))
        XCTAssertTrue(AppTab.allCases.contains(.ledger))
        XCTAssertTrue(AppTab.allCases.contains(.importReview))
        XCTAssertTrue(AppTab.allCases.contains(.accounts))
        XCTAssertTrue(AppTab.allCases.contains(.projects))
        XCTAssertTrue(AppTab.allCases.contains(.recurring))
        XCTAssertTrue(AppTab.allCases.contains(.rules))
        XCTAssertTrue(AppTab.allCases.contains(.data))

        let decoded = AppTab.decode("dashboard,inbox,reports,reports")

        XCTAssertEqual(decoded, [.dashboard, .importReview, .reports, .more])
    }
}

final class RecurringDetectorTests: XCTestCase {
    func testSuggestsRegularMonthlyExpense() {
        let calendar = Calendar(identifier: .gregorian)
        let dates = [
            DateComponents(year: 2026, month: 1, day: 1),
            DateComponents(year: 2026, month: 2, day: 1),
            DateComponents(year: 2026, month: 3, day: 1)
        ].map { calendar.date(from: $0)! }
        let transactions = dates.map {
            BudgetTransaction(date: $0, merchant: "Netflix", amount: 649, type: .expense)
        }

        let suggestions = RecurringDetector.suggestions(from: transactions, calendar: calendar)

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].displayName, "Netflix")
        XCTAssertEqual(suggestions[0].likelyFrequency, .monthly)
        XCTAssertEqual(suggestions[0].averageAmount, Decimal(649))
    }

    func testRejectsIrregularMerchantGaps() {
        let calendar = Calendar(identifier: .gregorian)
        let dates = [
            DateComponents(year: 2026, month: 1, day: 1),
            DateComponents(year: 2026, month: 1, day: 4),
            DateComponents(year: 2026, month: 3, day: 20),
            DateComponents(year: 2026, month: 5, day: 1)
        ].map { calendar.date(from: $0)! }
        let transactions = dates.map {
            BudgetTransaction(date: $0, merchant: "Amazon", amount: 999, type: .expense)
        }

        let suggestions = RecurringDetector.suggestions(from: transactions, calendar: calendar)

        XCTAssertTrue(suggestions.isEmpty)
    }
}
