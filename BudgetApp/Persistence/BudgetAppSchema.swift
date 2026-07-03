import Foundation
import SwiftData

enum BudgetAppSchema {
    static let schema = Schema([
        BudgetTransaction.self,
        BudgetCategory.self,
        BudgetAccount.self,
        RecurringPayment.self,
        ImportBatch.self,
        ImportRule.self,
        Project.self
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }
}
