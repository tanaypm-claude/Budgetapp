import Foundation
import SwiftData

/// First-run defaults and developer sample data. `seedIfNeeded` runs once on a
/// fresh store so the app is useful immediately; `loadSampleTransactions` and
/// `reset` are exposed for the debug-only data tools.
@MainActor
enum SeedData {

    /// Seed default categories, accounts and rules if the store is empty.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }
        seedDefaults(context: context)
        try? context.save()
    }

    static func seedDefaults(context: ModelContext) {
        let accounts = defaultAccounts()
        accounts.forEach { context.insert($0) }

        let categories = defaultCategories()
        categories.forEach { context.insert($0) }

        let byName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0.id) })
        defaultRules(categoryIds: byName).forEach { context.insert($0) }

        if let primary = accounts.first, let rentCat = byName["Rent"] {
            context.insert(RecurringPayment(
                name: "Apartment Rent",
                amount: 32000,
                categoryId: rentCat,
                accountId: primary.id,
                frequency: .monthly,
                nextExpectedDate: nextMonthDay(1)
            ))
        }
        if let primary = accounts.first, let subsCat = byName["Subscriptions"] {
            context.insert(RecurringPayment(
                name: "Streaming Bundle",
                amount: 649,
                categoryId: subsCat,
                accountId: primary.id,
                frequency: .monthly,
                nextExpectedDate: nextMonthDay(5)
            ))
        }
    }

    static func defaultAccounts() -> [Account] {
        [
            Account(name: "Primary Bank", type: .bank, openingBalance: 85000, currentBalance: 85000, sortOrder: 0),
            Account(name: "Credit Card", type: .creditCard, openingBalance: 0, currentBalance: 0, sortOrder: 1),
            Account(name: "Cash Wallet", type: .cash, openingBalance: 3000, currentBalance: 3000, sortOrder: 2)
        ]
    }

    static func defaultCategories() -> [Category] {
        [
            Category(name: "Food & Dining", symbol: "fork.knife", colorHex: "#C97C3C", monthlyBudget: 12000, sortOrder: 0),
            Category(name: "Groceries", symbol: "cart", colorHex: "#6FA86B", monthlyBudget: 9000, sortOrder: 1),
            Category(name: "Travel", symbol: "car.fill", colorHex: "#4C8CB5", monthlyBudget: 6000, sortOrder: 2),
            Category(name: "Rent", symbol: "house.fill", colorHex: "#9C6B9E", monthlyBudget: 32000, sortOrder: 3),
            Category(name: "Utilities", symbol: "bolt.fill", colorHex: "#D2A24C", monthlyBudget: 4000, sortOrder: 4),
            Category(name: "Shopping", symbol: "bag.fill", colorHex: "#C25E7A", monthlyBudget: 5000, sortOrder: 5),
            Category(name: "Subscriptions", symbol: "rectangle.stack.badge.play", colorHex: "#5E7CE2", monthlyBudget: 2000, sortOrder: 6),
            Category(name: "Health", symbol: "cross.case.fill", colorHex: "#6BB0A4", monthlyBudget: 3000, sortOrder: 7),
            Category(name: "Income", symbol: "arrow.down.circle.fill", colorHex: "#4F9D69", monthlyBudget: 0, sortOrder: 8)
        ]
    }

    static func defaultRules(categoryIds: [String: UUID]) -> [ImportRule] {
        var rules: [ImportRule] = []
        func rule(_ name: String, _ value: String, _ category: String, priority: Int, field: RuleMatchField = .merchant) {
            guard let id = categoryIds[category] else { return }
            rules.append(ImportRule(name: name, matchField: field, matchType: .contains,
                                    matchValue: value, categoryId: id, priority: priority))
        }
        rule("Swiggy → Food", "Swiggy", "Food & Dining", priority: 10)
        rule("Zomato → Food", "Zomato", "Food & Dining", priority: 11)
        rule("Uber → Travel", "Uber", "Travel", priority: 20)
        rule("Ola → Travel", "Ola", "Travel", priority: 21)
        rule("Rent → Rent", "rent", "Rent", priority: 30, field: .description)
        rule("BigBasket → Groceries", "BigBasket", "Groceries", priority: 40)
        rule("Electricity → Utilities", "electricity", "Utilities", priority: 50, field: .description)
        rule("Netflix → Subscriptions", "Netflix", "Subscriptions", priority: 60)
        rule("Amazon → Shopping", "Amazon", "Shopping", priority: 70)
        rule("Pharmacy → Health", "pharmacy", "Health", priority: 80, field: .description)
        return rules
    }

    // MARK: Sample transactions (debug data tools)

    static func loadSampleTransactions(context: ModelContext) {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        guard !categories.isEmpty, let bank = accounts.first else { return }
        let byName = Dictionary(categories.map { ($0.name, $0.id) }, uniquingKeysWith: { a, _ in a })

        func tx(_ daysAgo: Int, _ merchant: String, _ amount: Decimal, _ category: String, _ type: TransactionType = .expense) {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            context.insert(Transaction(
                date: date, merchant: merchant, narration: merchant, amount: amount, type: type,
                categoryId: byName[category], accountId: bank.id, source: .manual, isReviewed: true
            ))
        }

        tx(0, "Swiggy", 480, "Food & Dining")
        tx(1, "BigBasket", 2150, "Groceries")
        tx(2, "Uber", 320, "Travel")
        tx(3, "Netflix", 649, "Subscriptions")
        tx(5, "Amazon", 1899, "Shopping")
        tx(6, "Zomato", 560, "Food & Dining")
        tx(8, "Electricity Board", 1450, "Utilities")
        tx(10, "Apollo Pharmacy", 720, "Health")
        tx(12, "Ola", 240, "Travel")
        tx(1, "Acme Payroll", 95000, "Income", .income)
        try? context.save()
    }

    /// Wipe everything and re-seed defaults. Debug data tool.
    static func reset(context: ModelContext, withSamples: Bool) {
        try? BackupServiceSync.deleteAll(context: context)
        seedDefaults(context: context)
        if withSamples { loadSampleTransactions(context: context) }
        try? context.save()
    }

    // MARK: Helpers

    private static func nextMonthDay(_ day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: .now)
        components.month = (components.month ?? 1) + 1
        components.day = day
        return calendar.date(from: components) ?? .now
    }
}

/// Synchronous delete helper usable from `SeedData.reset` (which is already on
/// the main actor) without the full `BackupService` async surface.
enum BackupServiceSync {
    static func deleteAll(context: ModelContext) throws {
        try context.delete(model: Transaction.self)
        try context.delete(model: Category.self)
        try context.delete(model: Account.self)
        try context.delete(model: RecurringPayment.self)
        try context.delete(model: ImportRule.self)
        try context.delete(model: ImportBatch.self)
        try context.delete(model: Project.self)
    }
}
