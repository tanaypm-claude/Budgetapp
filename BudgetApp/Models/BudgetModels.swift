import Foundation
import SwiftData

enum TransactionType: String, CaseIterable, Codable, Identifiable {
    case income
    case expense
    case transfer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        }
    }
}

enum TransactionSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case csvImport
    case pdfImport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .csvImport: "CSV"
        case .pdfImport: "PDF"
        }
    }
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case bank
    case creditCard
    case cash
    case wallet
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bank: "Bank"
        case .creditCard: "Credit Card"
        case .cash: "Cash"
        case .wallet: "Wallet"
        case .other: "Other"
        }
    }
}

enum RecurringFrequency: String, CaseIterable, Codable, Identifiable {
    case weekly
    case fortnightly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }
}

enum ImportFileType: String, CaseIterable, Codable, Identifiable {
    case csv
    case pdf

    var id: String { rawValue }
}

enum ImportStatus: String, CaseIterable, Codable, Identifiable {
    case previewed
    case completed
    case partial
    case failed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .previewed: "Previewed"
        case .completed: "Completed"
        case .partial: "Partial"
        case .failed: "Failed"
        }
    }
}

enum RuleMatchField: String, CaseIterable, Codable, Identifiable {
    case merchant
    case description
    case amount
    case account

    var id: String { rawValue }

    var label: String {
        switch self {
        case .merchant: "Merchant"
        case .description: "Description"
        case .amount: "Amount"
        case .account: "Account"
        }
    }
}

enum RuleMatchType: String, CaseIterable, Codable, Identifiable {
    case contains
    case equals
    case startsWith
    case regex

    var id: String { rawValue }

    var label: String {
        switch self {
        case .contains: "Contains"
        case .equals: "Equals"
        case .startsWith: "Starts With"
        case .regex: "Regex"
        }
    }
}

@Model
final class BudgetTransaction: Identifiable {
    @Attribute(.unique) var id: UUID
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

    init(
        id: UUID = UUID(),
        date: Date,
        merchant: String,
        narration: String = "",
        amount: Decimal,
        type: TransactionType,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        projectId: UUID? = nil,
        source: TransactionSource = .manual,
        importId: UUID? = nil,
        note: String = "",
        isReviewed: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        fingerprint: String? = nil
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.narration = narration
        self.amount = amount.absoluteValue
        self.typeRaw = type.rawValue
        self.categoryId = categoryId
        self.accountId = accountId
        self.projectId = projectId
        self.sourceRaw = source.rawValue
        self.importId = importId
        self.note = note
        self.isReviewed = isReviewed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fingerprint = fingerprint ?? DedupingService.fingerprint(
            date: date,
            merchant: merchant,
            amount: amount.absoluteValue,
            accountId: accountId
        )
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set {
            typeRaw = newValue.rawValue
            touch()
        }
    }

    var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRaw) ?? .manual }
        set {
            sourceRaw = newValue.rawValue
            touch()
        }
    }

    var signedAmount: Decimal {
        switch type {
        case .income:
            return amount
        case .expense:
            return -amount
        case .transfer:
            return .zero
        }
    }

    func refreshFingerprint() {
        fingerprint = DedupingService.fingerprint(
            date: date,
            merchant: merchant,
            amount: amount,
            accountId: accountId
        )
        touch()
    }

    func touch() {
        updatedAt = Date()
    }
}

@Model
final class BudgetCategory: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var monthlyBudget: Decimal = 0
    var sortOrder: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        colorHex: String,
        monthlyBudget: Decimal,
        sortOrder: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.monthlyBudget = monthlyBudget
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() {
        updatedAt = Date()
    }
}

@Model
final class BudgetAccount: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var openingBalance: Decimal
    var currentBalance: Decimal
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        openingBalance: Decimal = 0,
        currentBalance: Decimal = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.openingBalance = openingBalance
        self.currentBalance = currentBalance
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .other }
        set {
            typeRaw = newValue.rawValue
            touch()
        }
    }

    func touch() {
        updatedAt = Date()
    }
}

@Model
final class RecurringPayment: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var categoryId: UUID?
    var accountId: UUID?
    var frequencyRaw: String
    var nextExpectedDate: Date
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        frequency: RecurringFrequency = .monthly,
        nextExpectedDate: Date,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount.absoluteValue
        self.categoryId = categoryId
        self.accountId = accountId
        self.frequencyRaw = frequency.rawValue
        self.nextExpectedDate = nextExpectedDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set {
            frequencyRaw = newValue.rawValue
            touch()
        }
    }

    func touch() {
        updatedAt = Date()
    }
}

@Model
final class ImportBatch: Identifiable {
    @Attribute(.unique) var id: UUID
    var filename: String
    var fileTypeRaw: String
    var importedAt: Date
    var rowCount: Int
    var statusRaw: String
    var message: String

    init(
        id: UUID = UUID(),
        filename: String,
        fileType: ImportFileType,
        importedAt: Date = Date(),
        rowCount: Int,
        status: ImportStatus,
        message: String = ""
    ) {
        self.id = id
        self.filename = filename
        self.fileTypeRaw = fileType.rawValue
        self.importedAt = importedAt
        self.rowCount = rowCount
        self.statusRaw = status.rawValue
        self.message = message
    }

    var fileType: ImportFileType {
        get { ImportFileType(rawValue: fileTypeRaw) ?? .csv }
        set { fileTypeRaw = newValue.rawValue }
    }

    var status: ImportStatus {
        get { ImportStatus(rawValue: statusRaw) ?? .previewed }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class ImportRule: Identifiable {
    @Attribute(.unique) var id: UUID
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

    init(
        id: UUID = UUID(),
        name: String,
        matchField: RuleMatchField,
        matchType: RuleMatchType,
        matchValue: String,
        categoryId: UUID?,
        accountId: UUID? = nil,
        priority: Int = 100,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.matchFieldRaw = matchField.rawValue
        self.matchTypeRaw = matchType.rawValue
        self.matchValue = matchValue
        self.categoryId = categoryId
        self.accountId = accountId
        self.priority = priority
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var matchField: RuleMatchField {
        get { RuleMatchField(rawValue: matchFieldRaw) ?? .merchant }
        set {
            matchFieldRaw = newValue.rawValue
            touch()
        }
    }

    var matchType: RuleMatchType {
        get { RuleMatchType(rawValue: matchTypeRaw) ?? .contains }
        set {
            matchTypeRaw = newValue.rawValue
            touch()
        }
    }

    func touch() {
        updatedAt = Date()
    }
}

@Model
final class Project: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var monthlyBudget: Decimal = 0
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        monthlyBudget: Decimal = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.monthlyBudget = monthlyBudget
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() {
        updatedAt = Date()
    }
}
