import XCTest
@testable import Budgetapp

final class ColumnMappingTests: XCTestCase {

    func testAutoDetectsCommonHeaders() {
        let mapping = ColumnMapping.autoDetect(headers: ["Date", "Merchant", "Description", "Amount", "Account"])
        XCTAssertEqual(mapping.header(for: .date), "Date")
        XCTAssertEqual(mapping.header(for: .merchant), "Merchant")
        XCTAssertEqual(mapping.header(for: .description), "Description")
        XCTAssertEqual(mapping.header(for: .amount), "Amount")
        XCTAssertEqual(mapping.header(for: .account), "Account")
    }

    func testAutoDetectsDebitCreditColumns() {
        let mapping = ColumnMapping.autoDetect(headers: ["Txn Date", "Narration", "Withdrawal", "Deposit", "Balance"])
        XCTAssertEqual(mapping.header(for: .date), "Txn Date")
        XCTAssertEqual(mapping.header(for: .description), "Narration")
        XCTAssertEqual(mapping.header(for: .debit), "Withdrawal")
        XCTAssertEqual(mapping.header(for: .credit), "Deposit")
    }

    func testEachHeaderClaimedOnce() {
        // "Date" should map to date, "Value Date" should not steal it twice.
        let mapping = ColumnMapping.autoDetect(headers: ["Date", "Value Date", "Amount"])
        let dateHeaders = mapping.assignments.filter { $0.value == "Date" }
        XCTAssertEqual(dateHeaders.count, 1)
    }

    func testValidityRequiresAmountSource() {
        var mapping = ColumnMapping(assignments: [.date: "Date", .merchant: "Merchant"])
        XCTAssertFalse(mapping.isValid)
        mapping.assignments[.amount] = "Amount"
        XCTAssertTrue(mapping.isValid)
    }

    func testValidWithOnlyDebitColumn() {
        let mapping = ColumnMapping(assignments: [.date: "Date", .debit: "Withdrawal"])
        XCTAssertTrue(mapping.isValid)
    }

    func testCaseInsensitiveDetection() {
        let mapping = ColumnMapping.autoDetect(headers: ["DATE", "AMOUNT"])
        XCTAssertEqual(mapping.header(for: .date), "DATE")
        XCTAssertEqual(mapping.header(for: .amount), "AMOUNT")
    }
}
