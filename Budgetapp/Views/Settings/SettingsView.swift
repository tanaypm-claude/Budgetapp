import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Preferences and data safety: JSON backup/restore, CSV export, and (in debug
/// builds only) sample-data tools. All offline; destructive actions confirm.
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var currencyCode = AppSettings.currencyCode
    @State private var hapticsEnabled = AppSettings.hapticsEnabled

    @State private var exportDocument: ShareableFile? = nil
    @State private var showingRestorePicker = false
    @State private var pendingRestoreURL: URL? = nil
    @State private var showingRestoreConfirm = false
    @State private var showingResetConfirm = false
    @State private var statusMessage: String? = nil

    var body: some View {
        Form {
            preferencesSection
            backupSection
            #if DEBUG
            developerSection
            #endif
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("Settings & Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportDocument) { file in
            ShareSheet(items: [file.url])
        }
        .fileImporter(isPresented: $showingRestorePicker,
                      allowedContentTypes: jsonTypes, allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                pendingRestoreURL = url
                showingRestoreConfirm = true
            }
        }
        .confirmationDialog("Replace all data with this backup?", isPresented: $showingRestoreConfirm, titleVisibility: .visible) {
            Button("Replace everything", role: .destructive) { performRestore() }
            Button("Cancel", role: .cancel) { pendingRestoreURL = nil }
        } message: {
            Text("This erases current data and restores the backup. This can't be undone.")
        }
        .confirmationDialog("Reset all data?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Reset & reseed", role: .destructive) { performReset(withSamples: false) }
            Button("Reset with sample data", role: .destructive) { performReset(withSamples: true) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Done", isPresented: Binding(
            get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(statusMessage ?? "") }
    }

    private var jsonTypes: [UTType] {
        var types: [UTType] = [.json]
        if let j = UTType(filenameExtension: "json") { types.append(j) }
        return types
    }

    // MARK: Sections

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Currency", selection: $currencyCode) {
                ForEach(AppSettings.supportedCurrencies, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: currencyCode) { _, newValue in AppSettings.currencyCode = newValue }

            Toggle("Haptics", isOn: $hapticsEnabled)
                .onChange(of: hapticsEnabled) { _, newValue in AppSettings.hapticsEnabled = newValue }
        }
    }

    private var backupSection: some View {
        Section {
            Button { exportJSON() } label: { Label("Export backup (JSON)", systemImage: "square.and.arrow.up") }
            Button { exportCSV() } label: { Label("Export transactions (CSV)", systemImage: "tablecells") }
            Button { showingRestorePicker = true } label: { Label("Restore from backup", systemImage: "square.and.arrow.down") }
        } header: {
            Text("Data safety")
        } footer: {
            Text("Backups are plain files you control. Nothing leaves this device unless you share it.")
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            Button { SeedData.loadSampleTransactions(context: context); statusMessage = "Sample transactions added." } label: {
                Label("Add sample transactions", systemImage: "wand.and.sparkles")
            }
            Button(role: .destructive) { showingResetConfirm = true } label: {
                Label("Reset data…", systemImage: "trash")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Visible in debug builds only.")
        }
    }
    #endif

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "Budgetapp")
            LabeledContent("Version", value: appVersion)
            LabeledContent("Storage", value: "On-device only")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return v
    }

    // MARK: Actions

    private func exportJSON() {
        do {
            let url = try BackupService.writeJSONFile(context: context)
            exportDocument = ShareableFile(url: url)
        } catch { statusMessage = "Export failed: \(error.localizedDescription)" }
    }

    private func exportCSV() {
        do {
            let url = try BackupService.writeCSVFile(context: context)
            exportDocument = ShareableFile(url: url)
        } catch { statusMessage = "Export failed: \(error.localizedDescription)" }
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        defer { pendingRestoreURL = nil }
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try BackupService.restore(from: data, context: context)
            Haptics.success()
            statusMessage = "Backup restored."
        } catch {
            statusMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func performReset(withSamples: Bool) {
        SeedData.reset(context: context, withSamples: withSamples)
        Haptics.warning()
        statusMessage = withSamples ? "Reset with sample data." : "Data reset."
    }
}

/// Identifiable wrapper so a generated file can drive `.sheet(item:)`.
struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Bridges `UIActivityViewController` for sharing exported files.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(PreviewData.container())
}
