import Foundation
import SwiftData

/// Deletes categories / accounts / projects without leaving dangling `UUID`
/// references on transactions, recurring payments, or rules. References are
/// cleared (set to `nil`) so history is preserved but never points at a
/// deleted record. Runs on the main actor because it mutates the live context.
@MainActor
enum DeletionService {

    // MARK: Category

    static func deleteCategory(_ category: Category, context: ModelContext) {
        clearCategoryReferences(category.id, context: context)
        context.delete(category)
        try? context.save()
    }

    static func clearCategoryReferences(_ id: UUID, context: ModelContext) {
        for txn in fetchTransactions(context) where txn.categoryId == id {
            txn.categoryId = nil
            txn.touch()
        }
        for payment in fetch(RecurringPayment.self, context) where payment.categoryId == id {
            payment.categoryId = nil
            payment.touch()
        }
        for rule in fetch(ImportRule.self, context) where rule.categoryId == id {
            rule.categoryId = nil
            rule.touch()
        }
    }

    // MARK: Account

    static func deleteAccount(_ account: Account, context: ModelContext) {
        clearAccountReferences(account.id, context: context)
        context.delete(account)
        try? context.save()
    }

    static func clearAccountReferences(_ id: UUID, context: ModelContext) {
        for txn in fetchTransactions(context) where txn.accountId == id {
            txn.accountId = nil
            txn.touch()
        }
        for payment in fetch(RecurringPayment.self, context) where payment.accountId == id {
            payment.accountId = nil
            payment.touch()
        }
        for rule in fetch(ImportRule.self, context) where rule.accountId == id {
            rule.accountId = nil
            rule.touch()
        }
    }

    // MARK: Project

    static func deleteProject(_ project: Project, context: ModelContext) {
        for txn in fetchTransactions(context) where txn.projectId == project.id {
            txn.projectId = nil
            txn.touch()
        }
        context.delete(project)
        try? context.save()
    }

    // MARK: Usage (for confirmation copy)

    static func transactionCount(categoryId: UUID, context: ModelContext) -> Int {
        fetchTransactions(context).filter { $0.categoryId == categoryId }.count
    }

    static func transactionCount(accountId: UUID, context: ModelContext) -> Int {
        fetchTransactions(context).filter { $0.accountId == accountId }.count
    }

    // MARK: Helpers

    private static func fetchTransactions(_ context: ModelContext) -> [Transaction] {
        (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
    }

    private static func fetch<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}
