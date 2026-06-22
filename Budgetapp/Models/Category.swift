import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    /// SF Symbol name used as the category glyph.
    var symbol: String
    /// Hex string (e.g. "#C97C3C") resolved to a `Color` in the UI layer.
    var colorHex: String
    var monthlyBudget: Decimal
    var sortOrder: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = "tag",
        colorHex: String = "#C97C3C",
        monthlyBudget: Decimal = 0,
        sortOrder: Int = 0,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
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

    func touch() { updatedAt = .now }
}
