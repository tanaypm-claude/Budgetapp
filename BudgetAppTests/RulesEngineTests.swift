import XCTest
@testable import BudgetApp

final class RulesEngineTests: XCTestCase {
    func testAppliesFirstMatchingRuleByPriority() {
        let foodId = UUID()
        let travelId = UUID()
        let lowPriority = ImportRule(
            name: "Generic",
            matchField: .merchant,
            matchType: .contains,
            matchValue: "Uber",
            categoryId: foodId,
            priority: 100
        )
        let highPriority = ImportRule(
            name: "Travel",
            matchField: .merchant,
            matchType: .contains,
            matchValue: "Uber",
            categoryId: travelId,
            priority: 10
        )
        var draft = DraftTransaction(
            date: Date(),
            merchant: "Uber Trip",
            amount: 300,
            type: .expense,
            source: .csvImport
        )

        RulesEngine.apply(to: &draft, rules: [lowPriority, highPriority])

        XCTAssertEqual(draft.categoryId, travelId)
        XCTAssertEqual(draft.appliedRuleId, highPriority.id)
        XCTAssertTrue(draft.isReviewed)
    }

    func testRegexMatching() {
        XCTAssertTrue(RulesEngine.matches(value: "UPI-SWIGGY-123", type: .regex, pattern: #"SWIGGY-\d+"#))
        XCTAssertFalse(RulesEngine.matches(value: "UPI-UBER", type: .regex, pattern: #"SWIGGY-\d+"#))
    }
}
