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

    enum LoadResult {
        case success(ModelContainer)
        case failure(Error)
    }

    /// Attempt to open the persistent, on-disk store. Unlike a silent in-memory
    /// fallback, a failure is surfaced so the user is never unknowingly typing
    /// into a throwaway store. The app presents a recovery screen on `.failure`.
    static func load() -> LoadResult {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return .success(try ModelContainer(for: schema, configurations: [configuration]))
        } catch {
            return .failure(error)
        }
    }

    /// An ephemeral container for SwiftUI previews and unit tests.
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // Force-try is acceptable here: an in-memory store has no external
        // failure modes, and a failure indicates a programmer error in the schema.
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// The default on-disk store files (store + its WAL/SHM sidecars).
    static func defaultStoreURLs() -> [URL] {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return [] }
        let base = appSupport.appendingPathComponent("default.store")
        return [
            base,
            appSupport.appendingPathComponent("default.store-shm"),
            appSupport.appendingPathComponent("default.store-wal")
        ]
    }

    /// Delete the on-disk store so a corrupt/incompatible store can be recreated.
    /// Destructive — callers confirm first.
    static func resetStore() throws {
        for url in defaultStoreURLs() where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
