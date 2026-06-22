import XCTest
@testable import Budgetapp

final class PDFStatementParserTests: XCTestCase {

    /// A realistic text-based statement with a running balance column.
    private let statement = """
    Account Statement
    Date        Description              Amount        Balance
    01/06/2026  SWIGGY BANGALORE         450.00        12,340.00
    02/06/2026  SALARY CREDIT            95,000.00     1,07,340.00
    03/06/2026  UBER TRIP                320.00        1,07,020.00
    Closing Balance                                    1,07,020.00
    """

    func testExtractsTransactionRows() {
        let rows = PDFStatementParser.parse(text: statement)
        XCTAssertEqual(rows.count, 3, "Header and closing-balance lines should be skipped")
    }

    func testInfersIncomeFromRisingBalance() {
        let rows = PDFStatementParser.parse(text: statement)
        let salary = rows[1]
        XCTAssertEqual(salary.type, .income)
        XCTAssertEqual(salary.amount, Decimal(95000))
    }

    func testInfersExpenseFromFallingBalance() {
        let rows = PDFStatementParser.parse(text: statement)
        let uber = rows[2]
        XCTAssertEqual(uber.type, .expense)
        XCTAssertEqual(uber.amount, Decimal(320))
    }

    func testFirstRowWithoutPriorBalanceNeedsReview() {
        let rows = PDFStatementParser.parse(text: statement)
        XCTAssertTrue(rows[0].needsReview)
    }

    func testExplicitCreditMarkerWins() {
        let text = "01/06/2026  REFUND FROM AMAZON   200.00 CR   5,000.00"
        let rows = PDFStatementParser.parse(text: text)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].type, .income)
        XCTAssertEqual(rows[0].amount, Decimal(200))
    }

    func testExtractsDescription() {
        let rows = PDFStatementParser.parse(text: statement)
        XCTAssertTrue(rows[0].merchant.contains("SWIGGY"))
    }

    func testParsesDate() {
        let rows = PDFStatementParser.parse(text: statement)
        XCTAssertNotNil(rows[0].date)
    }

    func testIgnoresLinesWithoutLeadingDate() {
        let text = "Some random narrative line with 100.00 in it"
        XCTAssertTrue(PDFStatementParser.parse(text: text).isEmpty)
    }

    func testSingleAmountLineParses() {
        let text = "15-Jun-2026  NETFLIX SUBSCRIPTION  649.00"
        let rows = PDFStatementParser.parse(text: text)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].amount, Decimal(649))
    }
}
