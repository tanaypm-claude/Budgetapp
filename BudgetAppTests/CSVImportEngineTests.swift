import XCTest
@testable import BudgetApp

final class CSVImportEngineTests: XCTestCase {
    func testParsesQuotedCSVAndDetectsMapping() throws {
        let csv = """
        Date,Description,Debit,Credit,Category
        2026-06-01,"Swiggy, Koramangala",450,,Food
        2026-06-02,Salary,,150000,Income
        """

        let document = try CSVImportEngine.parse(text: csv)

        XCTAssertEqual(document.headers, ["Date", "Description", "Debit", "Credit", "Category"])
        XCTAssertEqual(document.rows.count, 2)
        XCTAssertEqual(document.rows[0][1], "Swiggy, Koramangala")
        XCTAssertEqual(document.detectedMapping.date, "Date")
        XCTAssertEqual(document.detectedMapping.narration, "Description")
        XCTAssertEqual(document.detectedMapping.debit, "Debit")
        XCTAssertEqual(document.detectedMapping.credit, "Credit")
    }

    func testDetectMappingDoesNotTreatDescriptionAsCredit() throws {
        let document = try CSVImportEngine.parse(text: """
        Date,Description,Debit,Credit
        2026-06-01,Groceries,500.00,
        """)

        XCTAssertEqual(document.detectedMapping.date, "Date")
        XCTAssertEqual(document.detectedMapping.narration, "Description")
        XCTAssertEqual(document.detectedMapping.debit, "Debit")
        XCTAssertEqual(document.detectedMapping.credit, "Credit")
    }

    func testBuildsDraftsFromDebitAndCreditColumns() throws {
        let foodId = UUID()
        let csv = """
        Date,Description,Debit,Credit,Category
        2026-06-01,Swiggy,450,,Food
        2026-06-02,Salary,,150000,Income
        """
        let document = try CSVImportEngine.parse(text: csv)

        let drafts = try CSVImportEngine.drafts(
            from: document,
            mapping: document.detectedMapping,
            defaultAccountId: UUID(),
            categoryLookup: ["food": foodId]
        )

        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts[0].type, .expense)
        XCTAssertEqual(drafts[0].amount, Decimal(450))
        XCTAssertEqual(drafts[0].categoryId, foodId)
        XCTAssertTrue(drafts[0].isReviewed)
        XCTAssertEqual(drafts[1].type, .income)
        XCTAssertEqual(drafts[1].amount, Decimal(150000))
        XCTAssertFalse(drafts[1].isReviewed)
    }

    func testDraftResultSkipsBadRowsAndCollectsWarnings() throws {
        let csv = """
        Date,Description,Debit,Credit
        2026-06-01,Swiggy,450.00,
        Closing Balance,,,25000.00
        """
        let document = try CSVImportEngine.parse(text: csv)

        let result = try CSVImportEngine.draftResult(
            from: document,
            mapping: document.detectedMapping,
            defaultAccountId: nil,
            categoryLookup: [:]
        )

        XCTAssertEqual(result.drafts.count, 1)
        XCTAssertEqual(result.drafts[0].merchant, "Swiggy")
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertTrue(result.warnings[0].contains("Row 3 skipped"))
    }

    func testDraftResultThrowsWhenNoRowsAreUsable() throws {
        let csv = """
        Date,Description,Debit,Credit
        Closing Balance,,,25000.00
        """
        let document = try CSVImportEngine.parse(text: csv)

        XCTAssertThrowsError(try CSVImportEngine.draftResult(
            from: document,
            mapping: document.detectedMapping,
            defaultAccountId: nil,
            categoryLookup: [:]
        )) { error in
            guard case CSVImportError.noUsableRows = error else {
                return XCTFail("Expected noUsableRows, got \(error)")
            }
        }
    }

    func testAmountOnlyNegativeValuesBecomeExpenses() throws {
        let csv = """
        Date,Merchant,Amount
        2026-06-01,Uber,-320.50
        """
        let document = try CSVImportEngine.parse(text: csv)
        let drafts = try CSVImportEngine.drafts(
            from: document,
            mapping: document.detectedMapping,
            defaultAccountId: nil,
            categoryLookup: [:]
        )

        XCTAssertEqual(drafts.first?.type, .expense)
        XCTAssertEqual(drafts.first?.amount, Decimal(string: "320.50"))
    }
}
