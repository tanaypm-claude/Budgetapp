import XCTest
@testable import BudgetApp

final class DedupingServiceTests: XCTestCase {
    func testMarksLikelyDuplicateImports() {
        let accountId = UUID()
        let date = Date(timeIntervalSince1970: 1_780_262_400)
        let existing = BudgetTransaction(
            date: date,
            merchant: "Swiggy Order",
            amount: 450,
            type: .expense,
            accountId: accountId
        )
        let draft = DraftTransaction(
            date: date,
            merchant: "SWIGGY   ORDER",
            amount: 450,
            type: .expense,
            accountId: accountId,
            source: .csvImport
        )

        let marked = DedupingService.markDuplicates([draft], existing: [existing])

        XCTAssertTrue(marked[0].duplicateCandidate)
        XCTAssertFalse(marked[0].isReviewed)
    }
}
