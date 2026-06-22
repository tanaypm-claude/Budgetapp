import Foundation
import SwiftData

/// A single money movement. Related entities are referenced by `UUID` rather
/// than SwiftData relationships: it keeps the import/dedupe pipeline simple and
/// mirrors the spec's `categoryId` / `accountId` shape.
@Model
final class Transaction {
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
    var createdAt: Date
    var updatedAt: Date

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        merchant: String = "",
        narration: String = "",
        amount: Decimal = 0,
        type: TransactionType = .expense,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        projectId: UUID? = nil,
        source: TransactionSource = .manual,
        importId: UUID? = nil,
        note: String = "",
        isReviewed: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.narration = narration
        self.amount = amount
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
    }

    /// Magnitude of the amount, always non-negative.
    var magnitude: Decimal { amount < 0 ? -amount : amount }

    /// Signed effect on an account balance (income +, expense -, transfer 0).
    var signedBalanceEffect: Decimal { magnitude * type.balanceSign }

    func touch() { updatedAt = .now }
}
