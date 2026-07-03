import SwiftData
import SwiftUI

@main
struct TanayBudgetApp: App {
    private let container = BudgetAppSchema.makeContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(BudgetTheme.rust)
                .preferredColorScheme(.dark)
                .modelContainer(container)
        }
    }
}
