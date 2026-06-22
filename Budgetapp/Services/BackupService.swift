import Foundation
import SwiftData

/// Reads/writes the whole store as a JSON snapshot and exports transactions as
/// CSV. The pure encode/decode lives in `BackupCoder`; this type does the
/// SwiftData bridging.
@MainActor
enum BackupService {

    // MARK: Export

    static func makeSnapshot(context: ModelContext) throws -> BackupSnapshot {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let recurring = try context.fetch(FetchDescriptor<RecurringPayment>())
        let rules = try context.fetch(FetchDescriptor<ImportRule>())
        let batches = try context.fetch(FetchDescriptor<ImportBatch>())

        return BackupSnapshot(
            schemaVersion: BackupSnapshot.currentSchemaVersion,
            exportedAt: .now,
            accounts: accounts.map {
                AccountDTO(id: $0.id, name: $0.name, type: $0.type,
                           openingBalance: $0.openingBalance, currentBalance: $0.currentBalance,
                           isActive: $0.isActive, sortOrder: $0.sortOrder)
            },
            categories: categories.map {
                CategoryDTO(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex,
                            monthlyBudget: $0.monthlyBudget, sortOrder: $0.sortOrder, isActive: $0.isActive)
            },
            projects: projects.map {
                ProjectDTO(id: $0.id, name: $0.name, colorHex: $0.colorHex, isActive: $0.isActive)
            },
            transactions: transactions.map {
                TransactionDTO(id: $0.id, date: $0.date, merchant: $0.merchant, narration: $0.narration,
                               amount: $0.amount, type: $0.type, categoryId: $0.categoryId,
                               accountId: $0.accountId, projectId: $0.projectId, source: $0.source,
                               importId: $0.importId, note: $0.note, isReviewed: $0.isReviewed,
                               createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            recurringPayments: recurring.map {
                RecurringPaymentDTO(id: $0.id, name: $0.name, amount: $0.amount, categoryId: $0.categoryId,
                                    accountId: $0.accountId, frequency: $0.frequency,
                                    nextExpectedDate: $0.nextExpectedDate, isActive: $0.isActive, note: $0.note)
            },
            importRules: rules.map {
                ImportRuleDTO(id: $0.id, name: $0.name, matchField: $0.matchField, matchType: $0.matchType,
                              matchValue: $0.matchValue, categoryId: $0.categoryId, accountId: $0.accountId,
                              priority: $0.priority, isActive: $0.isActive)
            },
            importBatches: batches.map {
                ImportBatchDTO(id: $0.id, filename: $0.filename, fileType: $0.fileType,
                               importedAt: $0.importedAt, rowCount: $0.rowCount, status: $0.status,
                               duplicateCount: $0.duplicateCount, needsReviewCount: $0.needsReviewCount)
            }
        )
    }

    static func exportJSON(context: ModelContext) throws -> Data {
        try BackupCoder.encode(makeSnapshot(context: context))
    }

    /// Write a JSON backup to a temporary file and return its URL (for sharing).
    static func writeJSONFile(context: ModelContext) throws -> URL {
        let data = try exportJSON(context: context)
        let name = "Budgetapp-Backup-\(Self.timestamp()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Import / Restore

    /// Replace the entire store with a snapshot. Destructive — callers confirm
    /// first. Existing objects are deleted, then snapshot objects inserted.
    static func restore(snapshot: BackupSnapshot, context: ModelContext) throws {
        try deleteAll(context: context)

        for dto in snapshot.accounts {
            context.insert(Account(id: dto.id, name: dto.name, type: dto.type,
                                   openingBalance: dto.openingBalance, currentBalance: dto.currentBalance,
                                   isActive: dto.isActive, sortOrder: dto.sortOrder))
        }
        for dto in snapshot.categories {
            context.insert(Category(id: dto.id, name: dto.name, symbol: dto.symbol, colorHex: dto.colorHex,
                                    monthlyBudget: dto.monthlyBudget, sortOrder: dto.sortOrder, isActive: dto.isActive))
        }
        for dto in snapshot.projects {
            context.insert(Project(id: dto.id, name: dto.name, colorHex: dto.colorHex, isActive: dto.isActive))
        }
        for dto in snapshot.transactions {
            context.insert(Transaction(id: dto.id, date: dto.date, merchant: dto.merchant, narration: dto.narration,
                                       amount: dto.amount, type: dto.type, categoryId: dto.categoryId,
                                       accountId: dto.accountId, projectId: dto.projectId, source: dto.source,
                                       importId: dto.importId, note: dto.note, isReviewed: dto.isReviewed,
                                       createdAt: dto.createdAt, updatedAt: dto.updatedAt))
        }
        for dto in snapshot.recurringPayments {
            context.insert(RecurringPayment(id: dto.id, name: dto.name, amount: dto.amount, categoryId: dto.categoryId,
                                            accountId: dto.accountId, frequency: dto.frequency,
                                            nextExpectedDate: dto.nextExpectedDate, isActive: dto.isActive, note: dto.note))
        }
        for dto in snapshot.importRules {
            context.insert(ImportRule(id: dto.id, name: dto.name, matchField: dto.matchField, matchType: dto.matchType,
                                      matchValue: dto.matchValue, categoryId: dto.categoryId, accountId: dto.accountId,
                                      priority: dto.priority, isActive: dto.isActive))
        }
        for dto in snapshot.importBatches {
            context.insert(ImportBatch(id: dto.id, filename: dto.filename, fileType: dto.fileType,
                                       importedAt: dto.importedAt, rowCount: dto.rowCount, status: dto.status,
                                       duplicateCount: dto.duplicateCount, needsReviewCount: dto.needsReviewCount))
        }
        try context.save()
    }

    static func restore(from data: Data, context: ModelContext) throws {
        let snapshot = try BackupCoder.decode(data)
        try restore(snapshot: snapshot, context: context)
    }

    // MARK: CSV export

    static func transactionsCSV(context: ModelContext) throws -> String {
        let transactions = try context.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        let categories = try context.fetch(FetchDescriptor<Category>())
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let accountNames = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })

        var lines = ["Date,Merchant,Description,Amount,Type,Category,Account,Note"]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for txn in transactions {
            let fields = [
                dateFormatter.string(from: txn.date),
                txn.merchant,
                txn.narration,
                NSDecimalNumber(decimal: txn.amount).stringValue,
                txn.type.rawValue,
                txn.categoryId.flatMap { categoryNames[$0] } ?? "",
                txn.accountId.flatMap { accountNames[$0] } ?? "",
                txn.note
            ]
            lines.append(fields.map(escapeCSV).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func writeCSVFile(context: ModelContext) throws -> URL {
        let csv = try transactionsCSV(context: context)
        let name = "Budgetapp-Transactions-\(Self.timestamp()).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    // MARK: Helpers

    static func deleteAll(context: ModelContext) throws {
        try context.delete(model: Transaction.self)
        try context.delete(model: Category.self)
        try context.delete(model: Account.self)
        try context.delete(model: RecurringPayment.self)
        try context.delete(model: ImportRule.self)
        try context.delete(model: ImportBatch.self)
        try context.delete(model: Project.self)
        try context.save()
    }

    static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}
