import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Entry point for importing statements. Picks a CSV or PDF from Files, kicks
/// off parsing, and presents the import wizard. Also lists recent imports.
struct ImportLandingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ImportBatch.importedAt, order: .reverse) private var batches: [ImportBatch]

    @State private var showingCSVPicker = false
    @State private var showingPDFPicker = false
    @State private var wizardInput: ImportInputBox? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    intro
                    importButtons
                    if !batches.isEmpty { recentImports }
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.paper)
            .navigationTitle("Import")
            .fileImporter(isPresented: $showingCSVPicker,
                          allowedContentTypes: csvTypes, allowsMultipleSelection: false) { result in
                handlePick(result, fileType: .csv)
            }
            .fileImporter(isPresented: $showingPDFPicker,
                          allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handlePick(result, fileType: .pdf)
            }
            .sheet(item: $wizardInput) { box in
                ImportWizardView(input: box.input)
            }
            .alert("Couldn't import", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var csvTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .text]
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        return types
    }

    // MARK: Sections

    private var intro: some View {
        LedgerCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Label("Bring in your statements", systemImage: "tray.and.arrow.down")
                    .font(.ledgerHeadline()).foregroundStyle(Theme.ink)
                Text("Import a CSV export or a text-based PDF statement. You'll map columns, preview every row, and apply rules before anything is saved. Everything stays on this device.")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var importButtons: some View {
        VStack(spacing: Theme.Space.md) {
            ImportOptionButton(icon: "tablecells", title: "Import CSV",
                               subtitle: "Flexible column mapping") { showingCSVPicker = true }
            ImportOptionButton(icon: "doc.richtext", title: "Import PDF",
                               subtitle: "Text-based bank/card statements") { showingPDFPicker = true }
        }
    }

    private var recentImports: some View {
        let recent = Array(batches.prefix(8))
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionLabel("Recent imports")
            LedgerCard {
                VStack(spacing: Theme.Space.md) {
                    ForEach(recent) { batch in
                        ImportBatchRow(batch: batch)
                        if batch.id != recent.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
            }
        }
    }

    // MARK: File handling

    private func handlePick(_ result: Result<[URL], Error>, fileType: ImportFileType) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            loadFile(url, fileType: fileType)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadFile(_ url: URL, fileType: ImportFileType) {
        let service = ImportService(context: context)
        do {
            switch fileType {
            case .csv:
                let session = try service.loadCSV(url: url)
                wizardInput = ImportInputBox(input: .csv(session))
            case .pdf:
                let preview = try service.loadPDF(url: url)
                wizardInput = ImportInputBox(input: .pdfPreview(preview))
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct ImportOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: icon)
                    .font(.title2).foregroundStyle(Theme.accent).frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ledgerBody().weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkFaint)
            }
            .padding(Theme.Space.lg)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ImportBatchRow: View {
    let batch: ImportBatch

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: batch.fileType == .csv ? "tablecells" : "doc.richtext")
                .foregroundStyle(Theme.inkSecondary).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(batch.filename).font(.ledgerCaption().weight(.medium)).foregroundStyle(Theme.ink).lineLimit(1)
                Text("\(batch.rowCount) saved · \(batch.duplicateCount) dupes · \(batch.importedAt.shortDay)")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            StatusBadge(status: batch.status)
        }
    }
}

struct StatusBadge: View {
    let status: ImportStatus
    private var color: Color {
        switch status {
        case .completed: return Theme.positive
        case .partial: return Theme.warning
        case .failed: return Theme.negative
        case .pending: return Theme.inkSecondary
        }
    }
    var body: some View {
        Text(status.label).font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15)).foregroundStyle(color).clipShape(Capsule())
    }
}

/// Wrapper so the wizard input can drive `.sheet(item:)`.
struct ImportInputBox: Identifiable {
    let id = UUID()
    let input: ImportInput
}

enum ImportInput {
    case csv(ImportService.CSVSession)
    case pdfPreview(ImportPreview)
}

#Preview {
    ImportLandingView()
        .modelContainer(PreviewData.container())
}
