import Foundation
import SwiftData

struct BudgetBackup: Codable {
    var exportedAt: Date
    var transactions: [TransactionDTO]
    var categories: [CategoryDTO]
    var accounts: [AccountDTO]
    var recurringPayments: [RecurringPaymentDTO]
    var importBatches: [ImportBatchDTO]
    var importRules: [ImportRuleDTO]
    var projects: [ProjectDTO]
}

struct TransactionDTO: Codable {
    var id: UUID
    var date: Date
    var merchant: String
    var narration: String
    var amount: Decimal
    var typeRaw: String
    var categoryId: UUID?
    var accountId: UUID?
    var projectId: UUID?
    var sourceRaw: String
    var importId: UUID?
    var note: String
    var isReviewed: Bool
    var fingerprint: String
    var createdAt: Date
    var updatedAt: Date
}

struct CategoryDTO: Codable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var monthlyBudget: Decimal
    var sortOrder: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct AccountDTO: Codable {
    var id: UUID
    var name: String
    var typeRaw: String
    var openingBalance: Decimal
    var currentBalance: Decimal
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct RecurringPaymentDTO: Codable {
    var id: UUID
    var name: String
    var amount: Decimal
    var categoryId: UUID?
    var accountId: UUID?
    var frequencyRaw: String
    var nextExpectedDate: Date
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct ImportBatchDTO: Codable {
    var id: UUID
    var filename: String
    var fileTypeRaw: String
    var importedAt: Date
    var rowCount: Int
    var statusRaw: String
    var message: String
}

struct ImportRuleDTO: Codable {
    var id: UUID
    var name: String
    var matchFieldRaw: String
    var matchTypeRaw: String
    var matchValue: String
    var categoryId: UUID?
    var accountId: UUID?
    var priority: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct ProjectDTO: Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var monthlyBudget: Decimal
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex
        case monthlyBudget
        case isActive
        case createdAt
        case updatedAt
    }

    init(
        id: UUID,
        name: String,
        colorHex: String,
        monthlyBudget: Decimal = 0,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.monthlyBudget = monthlyBudget
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        monthlyBudget = try container.decodeIfPresent(Decimal.self, forKey: .monthlyBudget) ?? 0
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum BackupError: LocalizedError {
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The backup file could not be decoded."
        }
    }
}

enum BackupService {
    static func makeBackup(
        transactions: [BudgetTransaction],
        categories: [BudgetCategory],
        accounts: [BudgetAccount],
        recurringPayments: [RecurringPayment],
        importBatches: [ImportBatch],
        importRules: [ImportRule],
        projects: [Project]
    ) -> BudgetBackup {
        BudgetBackup(
            exportedAt: Date(),
            transactions: transactions.map(TransactionDTO.init),
            categories: categories.map(CategoryDTO.init),
            accounts: accounts.map(AccountDTO.init),
            recurringPayments: recurringPayments.map(RecurringPaymentDTO.init),
            importBatches: importBatches.map(ImportBatchDTO.init),
            importRules: importRules.map(ImportRuleDTO.init),
            projects: projects.map(ProjectDTO.init)
        )
    }

    static func encode(_ backup: BudgetBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(data: Data) throws -> BudgetBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(BudgetBackup.self, from: data)
        } catch {
            throw BackupError.invalidData
        }
    }

    static func importBackup(_ backup: BudgetBackup, into context: ModelContext, replaceExisting: Bool) throws {
        if replaceExisting {
            try deleteAll(in: context)
        }

        let existingCategoryIds = try Set(context.fetch(FetchDescriptor<BudgetCategory>()).map(\.id))
        let existingAccountIds = try Set(context.fetch(FetchDescriptor<BudgetAccount>()).map(\.id))
        let existingTransactionIds = try Set(context.fetch(FetchDescriptor<BudgetTransaction>()).map(\.id))
        let existingRecurringIds = try Set(context.fetch(FetchDescriptor<RecurringPayment>()).map(\.id))
        let existingBatchIds = try Set(context.fetch(FetchDescriptor<ImportBatch>()).map(\.id))
        let existingRuleIds = try Set(context.fetch(FetchDescriptor<ImportRule>()).map(\.id))
        let existingProjectIds = try Set(context.fetch(FetchDescriptor<Project>()).map(\.id))

        backup.categories.filter { !existingCategoryIds.contains($0.id) }.forEach { context.insert($0.model) }
        backup.accounts.filter { !existingAccountIds.contains($0.id) }.forEach { context.insert($0.model) }
        backup.projects.filter { !existingProjectIds.contains($0.id) }.forEach { context.insert($0.model) }
        backup.importBatches.filter { !existingBatchIds.contains($0.id) }.forEach { context.insert($0.model) }
        backup.importRules.filter { !existingRuleIds.contains($0.id) }.forEach { context.insert($0.model) }
        backup.recurringPayments.filter { !existingRecurringIds.contains($0.id) }.forEach { context.insert($0.model) }
        backup.transactions.filter { !existingTransactionIds.contains($0.id) }.forEach { context.insert($0.model) }

        try context.save()
    }

    static func transactionsCSV(transactions: [BudgetTransaction], categories: [BudgetCategory], accounts: [BudgetAccount]) -> String {
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let accountNames = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })
        let formatter = ISO8601DateFormatter()
        let header = ["date", "merchant", "description", "amount", "type", "category", "account", "source", "reviewed", "note"]
        let rows = transactions.sorted { $0.date > $1.date }.map { transaction in
            [
                formatter.string(from: transaction.date),
                transaction.merchant,
                transaction.narration,
                NSDecimalNumber(decimal: transaction.amount.roundedToPaise).stringValue,
                transaction.type.rawValue,
                transaction.categoryId.flatMap { categoryNames[$0] } ?? "",
                transaction.accountId.flatMap { accountNames[$0] } ?? "",
                transaction.source.rawValue,
                transaction.isReviewed ? "true" : "false",
                transaction.note
            ].map(csvEscape).joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n")
    }

    static func deleteAll(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<BudgetTransaction>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<RecurringPayment>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ImportRule>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ImportBatch>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Project>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<BudgetAccount>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<BudgetCategory>()).forEach { context.delete($0) }
        try context.save()
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

extension TransactionDTO {
    init(_ model: BudgetTransaction) {
        id = model.id
        date = model.date
        merchant = model.merchant
        narration = model.narration
        amount = model.amount
        typeRaw = model.typeRaw
        categoryId = model.categoryId
        accountId = model.accountId
        projectId = model.projectId
        sourceRaw = model.sourceRaw
        importId = model.importId
        note = model.note
        isReviewed = model.isReviewed
        fingerprint = model.fingerprint
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: BudgetTransaction {
        BudgetTransaction(
            id: id,
            date: date,
            merchant: merchant,
            narration: narration,
            amount: amount,
            type: TransactionType(rawValue: typeRaw) ?? .expense,
            categoryId: categoryId,
            accountId: accountId,
            projectId: projectId,
            source: TransactionSource(rawValue: sourceRaw) ?? .manual,
            importId: importId,
            note: note,
            isReviewed: isReviewed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fingerprint: fingerprint
        )
    }
}

extension CategoryDTO {
    init(_ model: BudgetCategory) {
        id = model.id
        name = model.name
        symbol = model.symbol
        colorHex = model.colorHex
        monthlyBudget = model.monthlyBudget
        sortOrder = model.sortOrder
        isActive = model.isActive
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: BudgetCategory {
        BudgetCategory(
            id: id,
            name: name,
            symbol: symbol,
            colorHex: colorHex,
            monthlyBudget: monthlyBudget,
            sortOrder: sortOrder,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension AccountDTO {
    init(_ model: BudgetAccount) {
        id = model.id
        name = model.name
        typeRaw = model.typeRaw
        openingBalance = model.openingBalance
        currentBalance = model.currentBalance
        isActive = model.isActive
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: BudgetAccount {
        BudgetAccount(
            id: id,
            name: name,
            type: AccountType(rawValue: typeRaw) ?? .other,
            openingBalance: openingBalance,
            currentBalance: currentBalance,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension RecurringPaymentDTO {
    init(_ model: RecurringPayment) {
        id = model.id
        name = model.name
        amount = model.amount
        categoryId = model.categoryId
        accountId = model.accountId
        frequencyRaw = model.frequencyRaw
        nextExpectedDate = model.nextExpectedDate
        isActive = model.isActive
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: RecurringPayment {
        RecurringPayment(
            id: id,
            name: name,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            frequency: RecurringFrequency(rawValue: frequencyRaw) ?? .monthly,
            nextExpectedDate: nextExpectedDate,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension ImportBatchDTO {
    init(_ model: ImportBatch) {
        id = model.id
        filename = model.filename
        fileTypeRaw = model.fileTypeRaw
        importedAt = model.importedAt
        rowCount = model.rowCount
        statusRaw = model.statusRaw
        message = model.message
    }

    var model: ImportBatch {
        ImportBatch(
            id: id,
            filename: filename,
            fileType: ImportFileType(rawValue: fileTypeRaw) ?? .csv,
            importedAt: importedAt,
            rowCount: rowCount,
            status: ImportStatus(rawValue: statusRaw) ?? .completed,
            message: message
        )
    }
}

extension ImportRuleDTO {
    init(_ model: ImportRule) {
        id = model.id
        name = model.name
        matchFieldRaw = model.matchFieldRaw
        matchTypeRaw = model.matchTypeRaw
        matchValue = model.matchValue
        categoryId = model.categoryId
        accountId = model.accountId
        priority = model.priority
        isActive = model.isActive
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: ImportRule {
        ImportRule(
            id: id,
            name: name,
            matchField: RuleMatchField(rawValue: matchFieldRaw) ?? .merchant,
            matchType: RuleMatchType(rawValue: matchTypeRaw) ?? .contains,
            matchValue: matchValue,
            categoryId: categoryId,
            accountId: accountId,
            priority: priority,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension ProjectDTO {
    init(_ model: Project) {
        id = model.id
        name = model.name
        colorHex = model.colorHex
        monthlyBudget = model.monthlyBudget
        isActive = model.isActive
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    var model: Project {
        Project(
            id: id,
            name: name,
            colorHex: colorHex,
            monthlyBudget: monthlyBudget,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
