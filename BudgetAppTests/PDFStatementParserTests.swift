import UIKit
import XCTest
@testable import BudgetApp

final class PDFStatementParserTests: XCTestCase {
    func testParsesTextBasedStatementLines() throws {
        let text = """
        Account statement
        01/06/2026 SWIGGY ORDER 450.00 25000.00
        02/06/2026 SALARY CREDIT 150000.00 CR 175000.00
        """

        let result = try PDFStatementParser.parse(text: text)

        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0].description, "SWIGGY ORDER")
        XCTAssertEqual(result.rows[0].debit, Decimal(450))
        XCTAssertEqual(result.rows[0].type, .expense)
        XCTAssertEqual(result.rows[1].credit, Decimal(150000))
        XCTAssertEqual(result.rows[1].type, .income)
    }

    func testIgnoresIntegerReferenceNumbersAsAmounts() throws {
        let text = """
        01/06/2026 ATM WDL 1234 500.00 12340.00
        """

        let result = try PDFStatementParser.parse(text: text)

        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0].description, "ATM WDL 1234")
        XCTAssertEqual(result.rows[0].debit, Decimal(500))
        XCTAssertEqual(result.rows[0].balance, Decimal(12340))
    }

    func testUsesRunningBalanceDeltaForDirection() throws {
        let text = """
        01/06/2026 ATM WITHDRAWAL 500.00 9500.00
        02/06/2026 AMAZON REFUND 200.00 9700.00
        """

        let result = try PDFStatementParser.parse(text: text)

        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0].type, .expense)
        XCTAssertEqual(result.rows[1].type, .income)
        XCTAssertEqual(result.rows[1].credit, Decimal(200))
    }

    func testThrowsWhenTextHasNoTransactions() {
        XCTAssertThrowsError(try PDFStatementParser.parse(text: "Opening balance only"))
    }

    func testRejectsPDFsAbovePageLimit() throws {
        let url = try makePDF(pageCount: PDFStatementParser.maxPageCount + 1)

        XCTAssertThrowsError(try PDFStatementParser.extractText(from: url)) { error in
            guard case let PDFStatementError.tooManyPages(pageCount, maxPages) = error else {
                XCTFail("Expected tooManyPages, got \(error)")
                return
            }
            XCTAssertEqual(pageCount, PDFStatementParser.maxPageCount + 1)
            XCTAssertEqual(maxPages, PDFStatementParser.maxPageCount)
        }
    }

    private func makePDF(pageCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("oversized-statement-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try renderer.writePDF(to: url) { context in
            for page in 1...pageCount {
                context.beginPage()
                "Page \(page)".draw(
                    in: CGRect(x: 48, y: 48, width: 500, height: 40),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 14)]
                )
            }
        }
        return url
    }
}
