import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BudgetTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private enum PlaintextExportKind: String, Identifiable {
    case backup
    case csv

    var id: String { rawValue }
}

private enum DataSafetyError: LocalizedError {
    case backupTooLarge(maxMegabytes: Int)

    var errorDescription: String? {
        switch self {
        case let .backupTooLarge(maxMegabytes):
            return "This backup file is too large to import safely. Use a JSON backup under \(maxMegabytes) MB."
        }
    }
}

struct DataSafetyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]
    @Query(sort: \RecurringPayment.nextExpectedDate) private var recurringPayments: [RecurringPayment]
    @Query(sort: \ImportBatch.importedAt, order: .reverse) private var importBatches: [ImportBatch]
    @Query(sort: \ImportRule.priority) private var importRules: [ImportRule]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var exportDocument = BudgetTextDocument()
    @State private var exportType: UTType = .json
    @State private var exportFilename = "tanay-budget-backup"
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var replaceExistingOnImport = false
    @State private var pendingBackup: BudgetBackup?
    @State private var pendingPlaintextExport: PlaintextExportKind?
    @State private var showingReplaceConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private static let maxBackupBytes = 15 * 1024 * 1024
    private static let maxBackupMegabytes = 15

    var body: some View {
        List {
            Section("Export Privacy") {
                Label("JSON and CSV exports are unencrypted plain text. Keep them in a private folder or encrypted drive.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(BudgetTheme.yellow)
            }

            Section("Backup") {
                Button {
                    pendingPlaintextExport = .backup
                } label: {
                    Label("Export JSON Backup", systemImage: "square.and.arrow.up")
                }

                Toggle("Replace existing data when restoring", isOn: $replaceExistingOnImport)

                Button {
                    showingImporter = true
                } label: {
                    Label("Import JSON Backup", systemImage: "square.and.arrow.down")
                }
            }

            Section("CSV") {
                Button {
                    pendingPlaintextExport = .csv
                } label: {
                    Label("Export Transactions CSV", systemImage: "tablecells")
                }
            }

            Section("On Device") {
                LabeledContent("Transactions", value: "\(transactions.count)")
                LabeledContent("Categories", value: "\(categories.count)")
                LabeledContent("Accounts", value: "\(accounts.count)")
                LabeledContent("Rules", value: "\(importRules.count)")
                Text("No backend, login, analytics, or tracking is configured. Files leave the device only when you export or share them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            Section("Development") {
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset and Seed Defaults", systemImage: "arrow.counterclockwise")
                }
            }
            #endif

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(BudgetTheme.moss)
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Data Safety")
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                statusMessage = "Export ready."
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            importBackup(from: result)
        }
        .confirmationDialog("Export unencrypted data?", isPresented: Binding(
            get: { pendingPlaintextExport != nil },
            set: { if !$0 { pendingPlaintextExport = nil } }
        ), titleVisibility: .visible) {
            if let pendingPlaintextExport {
                Button(pendingPlaintextExport == .backup ? "Export Plaintext Backup" : "Export Plaintext CSV") {
                    performPlaintextExport(pendingPlaintextExport)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingPlaintextExport = nil
            }
        } message: {
            Text("The exported file contains financial data in readable text. Share or store it only somewhere private.")
        }
        .confirmationDialog("Replace all existing data?", isPresented: $showingReplaceConfirmation, titleVisibility: .visible) {
            Button("Replace and Import", role: .destructive) {
                if let pendingBackup {
                    restore(pendingBackup, replaceExisting: true)
                }
                pendingBackup = nil
            }
            Button("Cancel", role: .cancel) {
                pendingBackup = nil
            }
        } message: {
            Text("This deletes the current local budget before importing the selected backup.")
        }
        #if DEBUG
        .confirmationDialog("Reset local data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                do {
                    try BackupService.deleteAll(in: modelContext)
                    SeedDataService.seedIfNeeded(in: modelContext)
                    statusMessage = "Development data reset."
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This is available only in debug builds.")
        }
        #endif
        .alert("Data Safety Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func exportBackup() {
        do {
            let backup = BackupService.makeBackup(
                transactions: transactions,
                categories: categories,
                accounts: accounts,
                recurringPayments: recurringPayments,
                importBatches: importBatches,
                importRules: importRules,
                projects: projects
            )
            let data = try BackupService.encode(backup)
            exportDocument = BudgetTextDocument(text: String(decoding: data, as: UTF8.self))
            exportType = .json
            exportFilename = "tanay-budget-backup"
            showingExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performPlaintextExport(_ kind: PlaintextExportKind) {
        pendingPlaintextExport = nil
        switch kind {
        case .backup:
            exportBackup()
        case .csv:
            exportTransactionsCSV()
        }
    }

    private func exportTransactionsCSV() {
        let csv = BackupService.transactionsCSV(transactions: transactions, categories: categories, accounts: accounts)
        exportDocument = BudgetTextDocument(text: csv)
        exportType = .commaSeparatedText
        exportFilename = "tanay-budget-transactions"
        showingExporter = true
    }

    private func importBackup(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try validateBackupSize(url)
            let data = try Data(contentsOf: url)
            let backup = try BackupService.decode(data: data)
            if replaceExistingOnImport {
                pendingBackup = backup
                showingReplaceConfirmation = true
            } else {
                restore(backup, replaceExisting: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateBackupSize(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > Self.maxBackupBytes {
            throw DataSafetyError.backupTooLarge(maxMegabytes: Self.maxBackupMegabytes)
        }
    }

    private func restore(_ backup: BudgetBackup, replaceExisting: Bool) {
        do {
            try BackupService.importBackup(backup, into: modelContext, replaceExisting: replaceExisting)
            statusMessage = replaceExisting ? "Backup restored." : "Backup merged."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
