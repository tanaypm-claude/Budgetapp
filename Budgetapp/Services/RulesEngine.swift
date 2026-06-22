import Foundation

/// Pure value representation of an `ImportRule`, evaluated by `RulesEngine`.
/// Keeping the engine value-based means matching is testable without a store.
struct RuleSpec: Identifiable, Equatable {
    let id: UUID
    var field: RuleMatchField
    var matchType: RuleMatchType
    var value: String
    var categoryId: UUID?
    var accountId: UUID?
    var priority: Int
    var isActive: Bool

    init(
        id: UUID = UUID(),
        field: RuleMatchField,
        matchType: RuleMatchType,
        value: String,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        priority: Int = 100,
        isActive: Bool = true
    ) {
        self.id = id
        self.field = field
        self.matchType = matchType
        self.value = value
        self.categoryId = categoryId
        self.accountId = accountId
        self.priority = priority
        self.isActive = isActive
    }
}

/// The fields a rule can match against, pulled from a transaction.
struct RuleInput {
    var merchant: String
    var description: String
    var amount: Decimal
    var accountName: String

    init(merchant: String = "", description: String = "", amount: Decimal = 0, accountName: String = "") {
        self.merchant = merchant
        self.description = description
        self.amount = amount
        self.accountName = accountName
    }
}

/// Outcome of applying the rule set: which category/account to assign and which
/// rule produced the match.
struct RuleOutcome: Equatable {
    var categoryId: UUID?
    var accountId: UUID?
    var matchedRuleId: UUID?

    var didMatch: Bool { matchedRuleId != nil }
}

enum RulesEngine {

    /// Apply rules in ascending `priority` order and return the first match.
    /// Inactive rules are ignored. Ties in priority are broken deterministically
    /// by rule id so behaviour is stable.
    static func firstMatch(rules: [RuleSpec], input: RuleInput) -> RuleOutcome {
        let ordered = rules
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        for rule in ordered where matches(rule: rule, input: input) {
            return RuleOutcome(
                categoryId: rule.categoryId,
                accountId: rule.accountId,
                matchedRuleId: rule.id
            )
        }
        return RuleOutcome(categoryId: nil, accountId: nil, matchedRuleId: nil)
    }

    /// Does a single rule match the input?
    static func matches(rule: RuleSpec, input: RuleInput) -> Bool {
        let fieldValue = value(for: rule.field, in: input)
        let needle = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }

        switch rule.matchType {
        case .contains:
            return fieldValue.localizedCaseInsensitiveContains(needle)
        case .equals:
            return fieldValue.compare(needle, options: .caseInsensitive) == .orderedSame
        case .startsWith:
            return fieldValue.lowercased().hasPrefix(needle.lowercased())
        case .regex:
            return regexMatches(pattern: needle, in: fieldValue)
        }
    }

    private static func value(for field: RuleMatchField, in input: RuleInput) -> String {
        switch field {
        case .merchant: return input.merchant
        case .description: return input.description
        case .account: return input.accountName
        case .amount: return NSDecimalNumber(decimal: input.amount).stringValue
        }
    }

    private static func regexMatches(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
