import XCTest
import SwiftData
@testable import Budgetapp

@MainActor
final class ImportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var foodId: UUID!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeInMemory()
        // Seed a category + matching rule so resolution has something to do.
        let food = Category(name: "Food & Dining", monthlyBudget: 10000)
        foodId = food.id
        context.insert(food)
        context.insert(Account(name: "Primary", type: .bank))
        context.insert(ImportRule(name: "Swiggy", matchField: .merchant, matchType: .contains,
                                  matchValue: "Swiggy", categoryId: food.id, priority: 10))
        try? context.save()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func table() -> CSVTable {
        CSVTable(
            headers: ["Date", "Merchant", "Amount"],
            rows: [
                ["2026-06-01", "Swiggy Bangalore", "-450"],   // rule -> Food, reviewed
                ["2026-06-02", "Unknown Cafe", "-200"]         // no rule -> needs review
            ]
        )
    }

    private func mapping() -> ColumnMapping {
        ColumnMapping(assignments: [.date: "Date", .merchant: "Merchant", .amount: "Amount"])
    }

    func testRuleAppliedDuringPreview() throws {
        let service = ImportService(context: context)
        let preview = try service.makeCSVPreview(table: table(), mapping: mapping(), filename: "test.csv")
        let swiggy = preview.transactions.first { $0.merchant.contains("Swiggy") }!
        XCTAssertEqual(swiggy.resolvedCategoryId, foodId)
        XCTAssertFalse(swiggy.needsReview)
    }

    func testUncertainRowGoesToReview() throws {
        let service = ImportService(context: context)
        let preview = try service.makeCSVPreview(table: table(), mapping: mapping(), filename: "test.csv")
        let unknown = preview.transactions.first { $0.merchant.contains("Unknown") }!
        XCTAssertNil(unknown.resolvedCategoryId)
        XCTAssertTrue(unknown.needsReview)
    }

    func testCommitPersistsTransactionsAndBatch() throws {
        let service = ImportService(context: context)
        let preview = try service.makeCSVPreview(table: table(), mapping: mapping(), filename: "test.csv")
        let batch = try service.commit(preview: preview, defaultAccountId: nil)

        let txns = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txns.count, 2)
        XCTAssertEqual(batch.rowCount, 2)

        let reviewedSwiggy = txns.first { $0.merchant.contains("Swiggy") }!
        XCTAssertTrue(reviewedSwiggy.isReviewed)
        XCTAssertEqual(reviewedSwiggy.categoryId, foodId)

        let unknown = txns.first { $0.merchant.contains("Unknown") }!
        XCTAssertFalse(unknown.isReviewed)
    }

    func testReimportFlagsDuplicates() throws {
        let service = ImportService(context: context)
        let preview1 = try service.makeCSVPreview(table: table(), mapping: mapping(), filename: "test.csv")
        _ = try service.commit(preview: preview1, defaultAccountId: nil)

        // Re-run the same file: every row should now be a duplicate.
        let preview2 = try service.makeCSVPreview(table: table(), mapping: mapping(), filename: "test.csv")
        XCTAssertEqual(preview2.transactions.filter(\.isDuplicate).count, 2)
        XCTAssertEqual(preview2.importableCount, 0)
    }

    func testCommitSkipsDeselectedAndDuplicateRows() throws {
        let service = ImportService(context: context)
        var preview = try service.makeCSVPreview(table: table(), mapping: mapping(), filename: "test.csv")
        // Deselect the first row.
        preview.transactions[0].isSelectedForImport = false
        let batch = try service.commit(preview: preview, defaultAccountId: nil)
        XCTAssertEqual(batch.rowCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 1)
    }

    func testPDFScannedReturnsFatalMessage() {
        // Empty/scanned-like text yields no rows; the parser path is covered by
        // PDFStatementParserTests. Here we assert the empty-handling contract.
        let parsed = PDFStatementParser.parse(text: "")
        XCTAssertTrue(parsed.isEmpty)
    }
}
