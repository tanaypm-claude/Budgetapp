import Foundation

protocol RuleMatchable {
    var ruleMerchant: String { get }
    var ruleDescription: String { get }
    var ruleAmount: Decimal { get }
    var ruleAccountName: String? { get }
}

extension BudgetTransaction: RuleMatchable {
    var ruleMerchant: String { merchant }
    var ruleDescription: String { narration }
    var ruleAmount: Decimal { amount }
    var ruleAccountName: String? { nil }
}

enum RulesEngine {
    static func matchingRule<T: RuleMatchable>(for item: T, rules: [ImportRule]) -> ImportRule? {
        rules
            .filter(\.isActive)
            .sorted {
                if $0.priority == $1.priority {
                    return $0.createdAt < $1.createdAt
                }
                return $0.priority < $1.priority
            }
            .first { matches(rule: $0, item: item) }
    }

    static func apply(to draft: inout DraftTransaction, rules: [ImportRule]) {
        guard let rule = matchingRule(for: draft, rules: rules) else { return }
        if let categoryId = rule.categoryId {
            draft.categoryId = categoryId
        }
        if let accountId = rule.accountId {
            draft.accountId = accountId
        }
        draft.appliedRuleId = rule.id
        draft.isReviewed = draft.categoryId != nil && !draft.duplicateCandidate
    }

    static func matches<T: RuleMatchable>(rule: ImportRule, item: T) -> Bool {
        let candidate: String
        switch rule.matchField {
        case .merchant:
            candidate = item.ruleMerchant
        case .description:
            candidate = item.ruleDescription
        case .amount:
            candidate = NSDecimalNumber(decimal: item.ruleAmount.roundedToPaise).stringValue
        case .account:
            candidate = item.ruleAccountName ?? ""
        }
        return matches(value: candidate, type: rule.matchType, pattern: rule.matchValue)
    }

    static func matches(value: String, type: RuleMatchType, pattern: String) -> Bool {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let expected = pattern.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .contains:
            return candidate.range(of: expected, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        case .equals:
            return candidate.compare(expected, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        case .startsWith:
            return candidate.range(of: expected, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
        case .regex:
            return candidate.range(of: expected, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
