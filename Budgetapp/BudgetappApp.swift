import SwiftUI
import SwiftData

@main
struct BudgetappApp: App {
    let container = PersistenceController.makeShared()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
