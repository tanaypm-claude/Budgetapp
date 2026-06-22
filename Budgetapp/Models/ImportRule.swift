import Foundation
import SwiftData

@Model
final class ImportRule {
    @Attribute(.unique) var id: UUID
    var name: String
    var matchFieldRaw: String
    var matchTypeRaw: String
    var matchValue: String
    var categoryId: UUID?
    var accountId: UUID?
    /// Lower numbers apply first.
    var priority: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    var matchField: RuleMatchField {
        get { RuleMatchField(rawValue: matchFieldRaw) ?? .merchant }
        set { matchFieldRaw = newValue.rawValue }
    }

    var matchType: RuleMatchType {
        get { RuleMatchType(rawValue: matchTypeRaw) ?? .contains }
        set { matchTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        matchField: RuleMatchField = .merchant,
        matchType: RuleMatchType = .contains,
        matchValue: String,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        priority: Int = 100,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
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

    func touch() { updatedAt = .now }

    /// Convert into the pure value type the `RulesEngine` evaluates.
    var spec: RuleSpec {
        RuleSpec(
            id: id,
            field: matchField,
            matchType: matchType,
            value: matchValue,
            categoryId: categoryId,
            accountId: accountId,
            priority: priority,
            isActive: isActive
        )
    }
}
