import Foundation

extension Array where Element == BudgetCategory {
    func category(id: UUID?) -> BudgetCategory? {
        guard let id else { return nil }
        return first { $0.id == id }
    }
}

extension Array where Element == BudgetAccount {
    func account(id: UUID?) -> BudgetAccount? {
        guard let id else { return nil }
        return first { $0.id == id }
    }
}
