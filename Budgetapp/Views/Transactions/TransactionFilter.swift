import Foundation

/// In-memory filter applied to the transaction list. Kept as a value type so the
/// filter sheet can edit a copy and apply on dismiss.
struct TransactionFilter: Equatable {
    var categoryId: UUID?
    var accountId: UUID?
    var type: TransactionType?
    var source: TransactionSource?
    var onlyNeedsReview: Bool = false
    var dateRange: DateRangeOption = .all

    enum DateRangeOption: String, CaseIterable, Identifiable {
        case all
        case thisMonth
        case lastMonth
        case last90

        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All time"
            case .thisMonth: return "This month"
            case .lastMonth: return "Last month"
            case .last90: return "Last 90 days"
            }
        }
    }

    var isActive: Bool {
        categoryId != nil || accountId != nil || type != nil || source != nil
            || onlyNeedsReview || dateRange != .all
    }

    var activeCount: Int {
        var count = 0
        if categoryId != nil { count += 1 }
        if accountId != nil { count += 1 }
        if type != nil { count += 1 }
        if source != nil { count += 1 }
        if onlyNeedsReview { count += 1 }
        if dateRange != .all { count += 1 }
        return count
    }

    /// Apply text search + structured filters to a list of transactions.
    func apply(to transactions: [Transaction], searchText: String, calendar: Calendar = .current) -> [Transaction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let now = Date.now

        return transactions.filter { txn in
            if let categoryId, txn.categoryId != categoryId { return false }
            if let accountId, txn.accountId != accountId { return false }
            if let type, txn.type != type { return false }
            if let source, txn.source != source { return false }
            if onlyNeedsReview, txn.isReviewed { return false }

            switch dateRange {
            case .all:
                break
            case .thisMonth:
                if !calendar.isDate(txn.date, equalTo: now, toGranularity: .month) { return false }
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                if !calendar.isDate(txn.date, equalTo: lastMonth, toGranularity: .month) { return false }
            case .last90:
                guard let cutoff = calendar.date(byAdding: .day, value: -90, to: now) else { break }
                if txn.date < cutoff { return false }
            }

            if !query.isEmpty {
                let haystack = "\(txn.merchant) \(txn.narration) \(txn.note)".lowercased()
                if !haystack.contains(query) { return false }
            }
            return true
        }
    }
}
