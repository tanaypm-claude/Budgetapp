import XCTest
@testable import Budgetapp

final class CSVTransactionMapperTests: XCTestCase {

    func testMapsSignedAmountColumn() {
        let mapping = ColumnMapping(assignments: [.date: "Date", .merchant: "Merchant", .amount: "Amount"])
        let table = CSVTable(headers: ["Date", "Merchant", "Amount"],
                             rows: [["2026-06-01", "Swiggy", "-450"], ["2026-06-02", "Salary", "95000"]])
        let result = CSVTransactionMapper.map(table: table, mapping: mapping)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].type, .expense)
        XCTAssertEqual(result[0].amount, Decimal(450))
        XCTAssertEqual(result[1].type, .income)
        XCTAssertEqual(result[1].amount, Decimal(95000))
    }

    func testNormalizesDebitCreditColumns() {
        let mapping = ColumnMapping(assignments: [.date: "Date", .description: "Desc", .debit: "Debit", .credit: "Credit"])
        let table = CSVTable(headers: ["Date", "Desc", "Debit", "Credit"],
                             rows: [["2026-06-01", "Rent", "32000", ""],
                                    ["2026-06-02", "Refund", "", "1200"]])
        let result = CSVTransactionMapper.map(table: table, mapping: mapping)
        XCTAssertEqual(result[0].type, .expense)
        XCTAssertEqual(result[0].amount, Decimal(32000))
        XCTAssertEqual(result[1].type, .income)
        XCTAssertEqual(result[1].amount, Decimal(1200))
    }

    func testRowWithoutAmountIsSkipped() {
        let mapping = ColumnMapping(assignments: [.date: "Date", .merchant: "Merchant", .amount: "Amount"])
        let table = CSVTable(headers: ["Date", "Merchant", "Amount"],
                             rows: [["2026-06-01", "Opening Balance", ""]])
        let result = CSVTransactionMapper.map(table: table, mapping: mapping)
        XCTAssertTrue(result.isEmpty)
    }

    func testBadDateFlagsNeedsReview() {
        let mapping = ColumnMapping(assignments: [.date: "Date", .merchant: "Merchant", .amount: "Amount"])
        let table = CSVTable(headers: ["Date", "Merchant", "Amount"],
                             rows: [["garbage", "Swiggy", "450"]])
        let result = CSVTransactionMapper.map(table: table, mapping: mapping)
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result[0].date)
        XCTAssertTrue(result[0].needsReview)
    }

    func testCarriesAccountAndCategoryNames() {
        let mapping = ColumnMapping(assignments: [.date: "Date", .merchant: "M", .amount: "A", .account: "Acc", .category: "Cat"])
        let table = CSVTable(headers: ["Date", "M", "A", "Acc", "Cat"],
                             rows: [["2026-06-01", "Swiggy", "-450", "HDFC", "Food"]])
        let result = CSVTransactionMapper.map(table: table, mapping: mapping)
        XCTAssertEqual(result[0].accountName, "HDFC")
        XCTAssertEqual(result[0].categoryName, "Food")
    }

    func testDebitTakesPrecedenceOverCreditWhenBothPresent() {
        let resolution = CSVTransactionMapper.resolveAmount(amount: "", debit: "500", credit: "")
        XCTAssertEqual(resolution.type, .expense)
        XCTAssertEqual(resolution.amount, Decimal(500))
    }
}
