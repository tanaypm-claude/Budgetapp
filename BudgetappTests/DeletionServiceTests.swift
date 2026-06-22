import XCTest
import SwiftData
@testable import Budgetapp

@MainActor
final class DeletionServiceTests: XCTestCase {

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

    func testDeletingCategoryClearsTransactionReference() throws {
        let category = Category(name: "Food")
        context.insert(category)
        let txn = Transaction(merchant: "Swiggy", amount: 450, type: .expense, categoryId: category.id)
        context.insert(txn)
        try context.save()

        DeletionService.deleteCategory(category, context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Category>()).count, 0)
        let saved = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(saved.count, 1, "Transaction is kept")
        XCTAssertNil(saved[0].categoryId, "but its category reference is cleared")
    }

    func testDeletingCategoryClearsRecurringAndRuleReferences() throws {
        let category = Category(name: "Rent")
        context.insert(category)
        let payment = RecurringPayment(name: "Rent", amount: 30000, categoryId: category.id)
        let rule = ImportRule(name: "rent", matchField: .description, matchType: .contains,
                              matchValue: "rent", categoryId: category.id)
        context.insert(payment)
        context.insert(rule)
        try context.save()

        DeletionService.deleteCategory(category, context: context)

        XCTAssertNil(try context.fetch(FetchDescriptor<RecurringPayment>()).first?.categoryId)
        XCTAssertNil(try context.fetch(FetchDescriptor<ImportRule>()).first?.categoryId)
    }

    func testDeletingAccountClearsTransactionReference() throws {
        let account = Account(name: "Primary", type: .bank)
        context.insert(account)
        let txn = Transaction(merchant: "Swiggy", amount: 450, type: .expense, accountId: account.id)
        context.insert(txn)
        try context.save()

        DeletionService.deleteAccount(account, context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Account>()).count, 0)
        let saved = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertNil(saved[0].accountId)
    }

    func testDeletingProjectClearsTransactionReference() throws {
        let project = Project(name: "Trip")
        context.insert(project)
        let txn = Transaction(merchant: "Hotel", amount: 5000, type: .expense, projectId: project.id)
        context.insert(txn)
        try context.save()

        DeletionService.deleteProject(project, context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Project>()).count, 0)
        XCTAssertNil(try context.fetch(FetchDescriptor<Transaction>()).first?.projectId)
    }

    func testUsageCounts() throws {
        let category = Category(name: "Food")
        let account = Account(name: "Primary", type: .bank)
        context.insert(category)
        context.insert(account)
        context.insert(Transaction(merchant: "A", amount: 1, type: .expense, categoryId: category.id, accountId: account.id))
        context.insert(Transaction(merchant: "B", amount: 1, type: .expense, categoryId: category.id))
        try context.save()

        XCTAssertEqual(DeletionService.transactionCount(categoryId: category.id, context: context), 2)
        XCTAssertEqual(DeletionService.transactionCount(accountId: account.id, context: context), 1)
    }
}
