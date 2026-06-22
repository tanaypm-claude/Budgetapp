import Foundation

/// The logical roles a CSV column can fill. The user confirms/overrides the
/// auto-detected mapping in the import screen.
enum CSVColumnRole: String, CaseIterable, Identifiable {
    case ignore
    case date
    case merchant
    case description
    case debit
    case credit
    case amount
    case account
    case category

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ignore: return "Ignore"
        case .date: return "Date"
        case .merchant: return "Merchant"
        case .description: return "Description"
        case .debit: return "Debit / Withdrawal"
        case .credit: return "Credit / Deposit"
        case .amount: return "Amount"
        case .account: return "Account"
        case .category: return "Category"
        }
    }

    /// Header keywords that hint at this role (lowercased, substring match).
    var keywords: [String] {
        switch self {
        case .ignore: return []
        case .date: return ["date", "txn date", "transaction date", "value date", "posting date"]
        case .merchant: return ["merchant", "payee", "name", "to/from", "party"]
        case .description: return ["description", "narration", "details", "particulars", "remarks", "memo"]
        case .debit: return ["debit", "withdrawal", "withdrawl", "paid out", "money out"]
        case .credit: return ["credit", "deposit", "paid in", "money in"]
        case .amount: return ["amount", "value", "transaction amount"]
        case .account: return ["account", "card", "source"]
        case .category: return ["category", "tag"]
        }
    }
}

/// A mapping from logical role to the CSV header name that fills it.
struct ColumnMapping: Equatable {
    /// role -> header name
    var assignments: [CSVColumnRole: String]

    init(assignments: [CSVColumnRole: String] = [:]) {
        self.assignments = assignments
    }

    func header(for role: CSVColumnRole) -> String? { assignments[role] }

    /// A mapping is usable only with a date, a name (merchant or description),
    /// and at least one amount source. Enforced before preview/commit.
    var isValid: Bool {
        let hasDate = assignments[.date] != nil
        let hasName = assignments[.merchant] != nil || assignments[.description] != nil
        let hasAmountSource = assignments[.amount] != nil
            || assignments[.debit] != nil
            || assignments[.credit] != nil
        return hasDate && hasName && hasAmountSource
    }

    var validationMessage: String? {
        guard !isValid else { return nil }
        var missing: [String] = []
        if assignments[.date] == nil { missing.append("a Date column") }
        if assignments[.merchant] == nil && assignments[.description] == nil {
            missing.append("a Merchant or Description column")
        }
        if assignments[.amount] == nil && assignments[.debit] == nil && assignments[.credit] == nil {
            missing.append("an Amount column (or Debit / Credit)")
        }
        return "Map " + missing.joined(separator: ", ") + " to continue."
    }

    /// Best-effort auto-detection from header names.
    static func autoDetect(headers: [String]) -> ColumnMapping {
        var assignments: [CSVColumnRole: String] = [:]
        let normalized = headers.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        // Roles ordered so more specific ones claim columns first.
        let order: [CSVColumnRole] = [.date, .debit, .credit, .amount, .merchant, .description, .account, .category]
        var taken = Set<Int>()

        // Find the first untaken header index matching `predicate`.
        func firstFreeIndex(where predicate: (String) -> Bool) -> Int? {
            for (index, header) in normalized.enumerated() where !taken.contains(index) {
                if predicate(header) { return index }
            }
            return nil
        }

        for role in order {
            // Pass 1: exact header match.
            var matchIndex = role.keywords.lazy
                .compactMap { keyword in firstFreeIndex(where: { $0 == keyword }) }
                .first
            // Pass 2: substring match.
            if matchIndex == nil {
                matchIndex = role.keywords.lazy
                    .compactMap { keyword in firstFreeIndex(where: { $0.contains(keyword) }) }
                    .first
            }
            if let index = matchIndex {
                assignments[role] = headers[index]
                taken.insert(index)
            }
        }
        return ColumnMapping(assignments: assignments)
    }
}
