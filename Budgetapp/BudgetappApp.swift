import SwiftUI
import SwiftData

@main
struct BudgetappApp: App {
    @State private var load = PersistenceController.load()

    var body: some Scene {
        WindowGroup {
            switch load {
            case let .success(container):
                RootView()
                    .tint(Theme.accent)
                    .modelContainer(container)
            case let .failure(error):
                StoreRecoveryView(error: error) {
                    load = PersistenceController.load()
                }
                .tint(Theme.accent)
            }
        }
    }
}
