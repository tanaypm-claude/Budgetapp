import Foundation
import SwiftData

/// Builds an in-memory container populated with seed defaults + sample
/// transactions, for SwiftUI previews. Never used in the shipping app.
@MainActor
enum PreviewData {
    static func container() -> ModelContainer {
        let container = PersistenceController.makeInMemory()
        let context = container.mainContext
        SeedData.seedDefaults(context: context)
        SeedData.loadSampleTransactions(context: context)
        try? context.save()
        return container
    }
}
