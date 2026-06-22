import Foundation
import SwiftData

/// Owns the SwiftData `ModelContainer`. The app uses an on-disk store; previews
/// and tests use in-memory containers.
enum PersistenceController {

    static let schema = Schema([
        Transaction.self,
        Category.self,
        Account.self,
        RecurringPayment.self,
        ImportBatch.self,
        ImportRule.self,
        Project.self
    ])

    /// The app's persistent, on-disk container.
    static func makeShared() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt/incompatible store should not hard-crash the user out of
            // their app silently; fall back to a fresh in-memory store so the UI
            // still runs, and surface the issue in the console.
            assertionFailure("Failed to create persistent ModelContainer: \(error)")
            return makeInMemory()
        }
    }

    /// An ephemeral container for SwiftUI previews and unit tests.
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // Force-try is acceptable here: an in-memory store has no external
        // failure modes, and a failure indicates a programmer error in the schema.
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
