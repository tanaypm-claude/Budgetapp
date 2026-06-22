import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var openingBalance: Decimal
    /// Manual override / last-known balance. The *live* balance is computed by
    /// `BudgetCalculator` from opening balance + transactions.
    var currentBalance: Decimal
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .bank }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType = .bank,
        openingBalance: Decimal = 0,
        currentBalance: Decimal = 0,
        isActive: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.openingBalance = openingBalance
        self.currentBalance = currentBalance
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() { updatedAt = .now }
}
