import Foundation

/// Codable mirror of the whole database. Stable field names so a backup written
/// today still imports into a future build. Decimals encode as JSON numbers.
struct BackupSnapshot: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var accounts: [AccountDTO]
    var categories: [CategoryDTO]
    var projects: [ProjectDTO]
    var transactions: [TransactionDTO]
    var recurringPayments: [RecurringPaymentDTO]
    var importRules: [ImportRuleDTO]
    var importBatches: [ImportBatchDTO]

    static let currentSchemaVersion = 1
}

struct AccountDTO: Codable {
    var id: UUID
    var name: String
    var type: AccountType
    var openingBalance: Decimal
    var currentBalance: Decimal
    var isActive: Bool
    var sortOrder: Int
}

struct CategoryDTO: Codable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var monthlyBudget: Decimal
    var sortOrder: Int
    var isActive: Bool
}

struct ProjectDTO: Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var isActive: Bool
}

struct TransactionDTO: Codable {
    var id: UUID
    var date: Date
    var merchant: String
    var narration: String
    var amount: Decimal
    var type: TransactionType
    var categoryId: UUID?
    var accountId: UUID?
    var projectId: UUID?
    var source: TransactionSource
    var importId: UUID?
    var note: String
    var isReviewed: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct RecurringPaymentDTO: Codable {
    var id: UUID
    var name: String
    var amount: Decimal
    var categoryId: UUID?
    var accountId: UUID?
    var frequency: RecurringFrequency
    var nextExpectedDate: Date
    var isActive: Bool
    var note: String
}

struct ImportRuleDTO: Codable {
    var id: UUID
    var name: String
    var matchField: RuleMatchField
    var matchType: RuleMatchType
    var matchValue: String
    var categoryId: UUID?
    var accountId: UUID?
    var priority: Int
    var isActive: Bool
}

struct ImportBatchDTO: Codable {
    var id: UUID
    var filename: String
    var fileType: ImportFileType
    var importedAt: Date
    var rowCount: Int
    var status: ImportStatus
    var duplicateCount: Int
    var needsReviewCount: Int
}

// MARK: - Encoding

enum BackupCoder {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode(_ snapshot: BackupSnapshot) throws -> Data {
        try encoder().encode(snapshot)
    }

    static func decode(_ data: Data) throws -> BackupSnapshot {
        try decoder().decode(BackupSnapshot.self, from: data)
    }
}
