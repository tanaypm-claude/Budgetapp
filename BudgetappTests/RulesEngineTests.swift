import XCTest
@testable import Budgetapp

final class RulesEngineTests: XCTestCase {

    private let food = UUID()
    private let travel = UUID()
    private let rent = UUID()

    private func rule(_ field: RuleMatchField, _ type: RuleMatchType, _ value: String,
                      category: UUID, priority: Int = 100, active: Bool = true) -> RuleSpec {
        RuleSpec(field: field, matchType: type, value: value, categoryId: category, priority: priority, isActive: active)
    }

    func testContainsMatch() {
        let rules = [rule(.merchant, .contains, "Swiggy", category: food)]
        let outcome = RulesEngine.firstMatch(rules: rules, input: RuleInput(merchant: "SWIGGY Bangalore"))
        XCTAssertEqual(outcome.categoryId, food)
    }

    func testCaseInsensitive() {
        let rules = [rule(.merchant, .contains, "uber", category: travel)]
        let outcome = RulesEngine.firstMatch(rules: rules, input: RuleInput(merchant: "UBER *TRIP"))
        XCTAssertEqual(outcome.categoryId, travel)
    }

    func testDescriptionFieldMatch() {
        let rules = [rule(.description, .contains, "rent", category: rent)]
        let outcome = RulesEngine.firstMatch(rules: rules, input: RuleInput(description: "Monthly RENT payment"))
        XCTAssertEqual(outcome.categoryId, rent)
    }

    func testEqualsMatch() {
        let rules = [rule(.merchant, .equals, "Netflix", category: food)]
        XCTAssertTrue(RulesEngine.matches(rule: rules[0], input: RuleInput(merchant: "netflix")))
        XCTAssertFalse(RulesEngine.matches(rule: rules[0], input: RuleInput(merchant: "Netflix India")))
    }

    func testStartsWithMatch() {
        let r = rule(.merchant, .startsWith, "Amaz", category: food)
        XCTAssertTrue(RulesEngine.matches(rule: r, input: RuleInput(merchant: "Amazon Pay")))
        XCTAssertFalse(RulesEngine.matches(rule: r, input: RuleInput(merchant: "Pay Amazon")))
    }

    func testRegexMatch() {
        let r = rule(.description, .regex, "^UPI/[0-9]+", category: travel)
        XCTAssertTrue(RulesEngine.matches(rule: r, input: RuleInput(description: "UPI/123456/uber")))
        XCTAssertFalse(RulesEngine.matches(rule: r, input: RuleInput(description: "NEFT transfer")))
    }

    func testPriorityOrderWins() {
        let rules = [
            rule(.merchant, .contains, "a", category: travel, priority: 50),
            rule(.merchant, .contains, "a", category: food, priority: 10)
        ]
        let outcome = RulesEngine.firstMatch(rules: rules, input: RuleInput(merchant: "abc"))
        XCTAssertEqual(outcome.categoryId, food, "Lower priority number should win")
    }

    func testInactiveRulesIgnored() {
        let rules = [rule(.merchant, .contains, "Swiggy", category: food, priority: 10, active: false)]
        let outcome = RulesEngine.firstMatch(rules: rules, input: RuleInput(merchant: "Swiggy"))
        XCTAssertNil(outcome.categoryId)
        XCTAssertFalse(outcome.didMatch)
    }

    func testNoMatchReturnsEmptyOutcome() {
        let rules = [rule(.merchant, .contains, "Swiggy", category: food)]
        let outcome = RulesEngine.firstMatch(rules: rules, input: RuleInput(merchant: "Zomato"))
        XCTAssertFalse(outcome.didMatch)
    }

    func testEmptyValueNeverMatches() {
        let r = rule(.merchant, .contains, "   ", category: food)
        XCTAssertFalse(RulesEngine.matches(rule: r, input: RuleInput(merchant: "anything")))
    }

    func testAmountFieldMatch() {
        let r = rule(.amount, .contains, "450", category: food)
        XCTAssertTrue(RulesEngine.matches(rule: r, input: RuleInput(amount: Decimal(450))))
    }

    func testRuleCanSetAccount() {
        let account = UUID()
        let r = RuleSpec(field: .merchant, matchType: .contains, value: "HDFC", categoryId: food, accountId: account)
        let outcome = RulesEngine.firstMatch(rules: [r], input: RuleInput(merchant: "HDFC ATM"))
        XCTAssertEqual(outcome.accountId, account)
    }
}
