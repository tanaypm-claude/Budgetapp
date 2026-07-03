import Foundation
import SwiftData

enum SeedDataService {
    static func seedIfNeeded(in context: ModelContext) {
        do {
            var descriptor = FetchDescriptor<BudgetCategory>()
            descriptor.fetchLimit = 1
            let existingCategories = try context.fetch(descriptor)
            guard existingCategories.isEmpty else { return }

            let food = BudgetCategory(name: "Food", symbol: "fork.knife", colorHex: "#0E0B09", monthlyBudget: 22000, sortOrder: 0)
            let travel = BudgetCategory(name: "Travel", symbol: "tram.fill", colorHex: "#0E0B09", monthlyBudget: 12000, sortOrder: 1)
            let rent = BudgetCategory(name: "Rent", symbol: "house.fill", colorHex: "#750609", monthlyBudget: 60000, sortOrder: 2)
            let utilities = BudgetCategory(name: "Utilities", symbol: "bolt.fill", colorHex: "#0E0B09", monthlyBudget: 8000, sortOrder: 3)
            let health = BudgetCategory(name: "Health", symbol: "cross.case.fill", colorHex: "#0E0B09", monthlyBudget: 6000, sortOrder: 4)
            let fun = BudgetCategory(name: "Fun", symbol: "sparkles", colorHex: "#750609", monthlyBudget: 10000, sortOrder: 5)
            let income = BudgetCategory(name: "Income", symbol: "arrow.down.circle.fill", colorHex: "#0E0B09", monthlyBudget: 0, sortOrder: 6)

            let account = BudgetAccount(name: "Primary Bank", type: .bank, openingBalance: 0, currentBalance: 0)
            let card = BudgetAccount(name: "Credit Card", type: .creditCard, openingBalance: 0, currentBalance: 0)
            let cash = BudgetAccount(name: "Cash", type: .cash, openingBalance: 0, currentBalance: 0)

            [food, travel, rent, utilities, health, fun, income].forEach { context.insert($0) }
            [account, card, cash].forEach { context.insert($0) }

            let rules = [
                ImportRule(name: "Swiggy to Food", matchField: .merchant, matchType: .contains, matchValue: "Swiggy", categoryId: food.id, priority: 10),
                ImportRule(name: "Uber to Travel", matchField: .merchant, matchType: .contains, matchValue: "Uber", categoryId: travel.id, priority: 20),
                ImportRule(name: "Rent narration", matchField: .description, matchType: .contains, matchValue: "rent", categoryId: rent.id, priority: 30)
            ]
            rules.forEach { context.insert($0) }

            let calendar = Calendar.current
            if let nextRent = calendar.nextDate(after: Date(), matching: DateComponents(day: 1), matchingPolicy: .nextTime) {
                context.insert(RecurringPayment(name: "Rent", amount: 60000, categoryId: rent.id, accountId: account.id, frequency: .monthly, nextExpectedDate: nextRent))
            }

            try context.save()
        } catch {
            assertionFailure("Seed failed: \(error)")
        }
    }
}
