import XCTest
import SwiftData
@testable import Budgetapp

@MainActor
final class ReviewQueueTransitionTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeInMemory()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func unreviewed() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>()).filter { !$0.isReviewed }
    }

    func testAssigningCategoryRemovesFromQueue() throws {
        let category = Category(name: "Food")
        context.insert(category)
        let txn = Transaction(merchant: "Unknown", amount: 200, type: .expense,
                              source: .csvImport, isReviewed: false)
        context.insert(txn)
        try context.save()

        XCTAssertEqual(try unreviewed().count, 1)

        // Mirror the review action: assign + mark reviewed.
        txn.categoryId = category.id
        txn.isReviewed = true
        txn.touch()
        try context.save()

        XCTAssertEqual(try unreviewed().count, 0)
        XCTAssertEqual(txn.categoryId, category.id)
    }

    func testMarkingReviewedKeepsCategory() throws {
        let category = Category(name: "Travel")
        context.insert(category)
        let txn = Transaction(merchant: "Uber", amount: 320, type: .expense,
                              categoryId: category.id, source: .csvImport, isReviewed: false)
        context.insert(txn)
        try context.save()

        txn.isReviewed = true
        try context.save()

        XCTAssertEqual(try unreviewed().count, 0)
        XCTAssertEqual(txn.categoryId, category.id)
    }

    func testReviewedTransactionsNotInQueue() throws {
        context.insert(Transaction(merchant: "Manual", amount: 100, type: .expense, isReviewed: true))
        try context.save()
        XCTAssertEqual(try unreviewed().count, 0)
    }

    func testTogglingBackToUnreviewedReAddsToQueue() throws {
        let txn = Transaction(merchant: "X", amount: 100, type: .expense, isReviewed: true)
        context.insert(txn)
        try context.save()
        XCTAssertEqual(try unreviewed().count, 0)

        txn.isReviewed = false
        try context.save()
        XCTAssertEqual(try unreviewed().count, 1)
    }
}
