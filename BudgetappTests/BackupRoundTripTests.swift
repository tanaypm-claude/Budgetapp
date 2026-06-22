import XCTest
import SwiftData
@testable import Budgetapp

@MainActor
final class BackupRoundTripTests: XCTestCase {

    private func makeContext() -> ModelContext {
        PersistenceController.makeInMemory().mainContext
    }

    func testSnapshotEncodesAndDecodes() throws {
        let context = makeContext()
        SeedData.seedDefaults(context: context)
        SeedData.loadSampleTransactions(context: context)
        try context.save()

        let data = try BackupService.exportJSON(context: context)
        let snapshot = try BackupCoder.decode(data)

        XCTAssertEqual(snapshot.schemaVersion, BackupSnapshot.currentSchemaVersion)
        XCTAssertFalse(snapshot.categories.isEmpty)
        XCTAssertFalse(snapshot.transactions.isEmpty)
    }

    func testRestoreReplacesData() throws {
        // Source store with data.
        let source = makeContext()
        SeedData.seedDefaults(context: source)
        SeedData.loadSampleTransactions(context: source)
        try source.save()
        let snapshot = try BackupService.makeSnapshot(context: source)
        let categoryCount = snapshot.categories.count
        let txnCount = snapshot.transactions.count

        // Fresh destination store with unrelated data.
        let destination = makeContext()
        destination.insert(Category(name: "Throwaway"))
        try destination.save()

        try BackupService.restore(snapshot: snapshot, context: destination)

        let restoredCategories = try destination.fetch(FetchDescriptor<Category>())
        let restoredTxns = try destination.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(restoredCategories.count, categoryCount)
        XCTAssertEqual(restoredTxns.count, txnCount)
        XCTAssertFalse(restoredCategories.contains { $0.name == "Throwaway" })
    }

    func testTransactionCSVHasHeaderAndRows() throws {
        let context = makeContext()
        SeedData.seedDefaults(context: context)
        SeedData.loadSampleTransactions(context: context)
        try context.save()

        let csv = try BackupService.transactionsCSV(context: context)
        let lines = csv.split(separator: "\n")
        XCTAssertTrue(lines.first?.contains("Date,Merchant") ?? false)
        XCTAssertGreaterThan(lines.count, 1)
    }

    func testCSVEscaping() {
        XCTAssertEqual(BackupService.escapeCSV("plain"), "plain")
        XCTAssertEqual(BackupService.escapeCSV("a,b"), "\"a,b\"")
        XCTAssertEqual(BackupService.escapeCSV("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testDateRoundTripsThroughDTO() throws {
        let context = makeContext()
        let original = Transaction(date: ValueParsing.parseDate("2026-06-22")!, merchant: "Swiggy",
                                   amount: 450, type: .expense)
        context.insert(original)
        try context.save()

        let data = try BackupService.exportJSON(context: context)
        let snapshot = try BackupCoder.decode(data)
        XCTAssertEqual(snapshot.transactions.count, 1)
        XCTAssertEqual(snapshot.transactions[0].merchant, "Swiggy")
        XCTAssertEqual(snapshot.transactions[0].amount, Decimal(450))
    }

    // MARK: Corrupt / mismatched backups fail loudly (and don't wipe data)

    func testDecodeRejectsGarbage() {
        let garbage = Data("this is not json".utf8)
        XCTAssertThrowsError(try BackupCoder.decode(garbage))
    }

    func testDecodeRejectsMismatchedJSON() {
        // Valid JSON, wrong shape for a BackupSnapshot.
        let mismatched = Data(#"{"foo": 1, "bar": [1,2,3]}"#.utf8)
        XCTAssertThrowsError(try BackupCoder.decode(mismatched))
    }

    func testRestoreFromCorruptDataThrowsAndKeepsExistingData() throws {
        let context = makeContext()
        SeedData.seedDefaults(context: context)
        try context.save()
        let categoriesBefore = try context.fetch(FetchDescriptor<Category>()).count
        XCTAssertGreaterThan(categoriesBefore, 0)

        // A failed restore must throw before deleting anything.
        XCTAssertThrowsError(try BackupService.restore(from: Data("nope".utf8), context: context))

        let categoriesAfter = try context.fetch(FetchDescriptor<Category>()).count
        XCTAssertEqual(categoriesAfter, categoriesBefore, "Existing data is untouched when the backup is invalid")
    }
}
