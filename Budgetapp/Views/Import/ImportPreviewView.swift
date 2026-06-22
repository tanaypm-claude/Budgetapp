import SwiftUI
import SwiftData

/// Final review before saving an import. Shows every parsed row with its
/// resolved category, duplicate/needs-review flags, and a per-row include
/// toggle. Saving writes the selected rows and records an `ImportBatch`.
struct ImportPreviewView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let preview: ImportPreview
    let onClose: () -> Void

    @State private var rows: [ParsedTransaction]
    @State private var defaultAccountId: UUID? = nil
    @State private var savedBatch: ImportBatch? = nil
    @State private var errorMessage: String? = nil

    init(preview: ImportPreview, onClose: @escaping () -> Void) {
        self.preview = preview
        self.onClose = onClose
        _rows = State(initialValue: preview.transactions)
    }

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }
    private var selectedCount: Int { rows.filter { $0.isSelectedForImport && !$0.isDuplicate }.count }
    private var duplicateCount: Int { rows.filter(\.isDuplicate).count }
    private var reviewCount: Int { rows.filter { $0.isSelectedForImport && $0.needsReview && !$0.isDuplicate }.count }

    var body: some View {
        Group {
            if let batch = savedBatch {
                ImportSummaryView(batch: batch, onDone: onClose)
            } else {
                content
            }
        }
        .background(Theme.paper)
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if savedBatch == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save \(selectedCount)") { commit() }
                        .disabled(selectedCount == 0).fontWeight(.semibold)
                }
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        .onAppear { if defaultAccountId == nil { defaultAccountId = accounts.first(where: \.isActive)?.id } }
    }

    private var content: some View {
        List {
            summarySection
            if !preview.warnings.isEmpty { warningsSection }
            accountSection
            rowsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: Theme.Space.lg) {
                stat("\(selectedCount)", "to save", Theme.positive)
                stat("\(duplicateCount)", "duplicates", Theme.inkSecondary)
                stat("\(reviewCount)", "to review", Theme.warning)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Theme.surfaceSunken)
        }
    }

    private var warningsSection: some View {
        Section {
            ForEach(preview.warnings, id: \.self) { warning in
                Label(warning, systemImage: "info.circle")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var accountSection: some View {
        Section("Assign to account") {
            Picker("Account", selection: $defaultAccountId) {
                Text("None").tag(UUID?.none)
                ForEach(accounts.filter(\.isActive)) { Label($0.name, systemImage: $0.type.symbolName).tag(Optional($0.id)) }
            }
        }
    }

    private var rowsSection: some View {
        Section("\(rows.count) rows") {
            ForEach($rows) { $row in
                ImportPreviewRow(row: $row, lookups: lookups)
            }
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.ledgerNumber(.title3, weight: .bold)).foregroundStyle(color)
            Text(label).font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
        }
    }

    private func commit() {
        var finalPreview = preview
        finalPreview.transactions = rows
        let service = ImportService(context: context)
        do {
            let batch = try service.commit(preview: finalPreview, defaultAccountId: defaultAccountId)
            Haptics.success()
            withAnimation { savedBatch = batch }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A single editable preview row.
struct ImportPreviewRow: View {
    @Binding var row: ParsedTransaction
    let lookups: Lookups

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Button {
                row.isSelectedForImport.toggle()
                Haptics.selection()
            } label: {
                Image(systemName: row.isSelectedForImport && !row.isDuplicate ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.isSelectedForImport && !row.isDuplicate ? Theme.positive : Theme.inkFaint)
            }
            .buttonStyle(.plain)
            .disabled(row.isDuplicate)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName).font(.ledgerBody().weight(.medium))
                    .foregroundStyle(row.isDuplicate ? Theme.inkFaint : Theme.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Text(row.date?.shortDay ?? "No date")
                    Text("·")
                    Text(lookups.categoryName(row.resolvedCategoryId))
                }
                .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary).lineLimit(1)

                if !row.issues.isEmpty {
                    Text(row.issues.joined(separator: " · "))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(row.isDuplicate ? Theme.inkFaint : Theme.warning)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(CurrencyFormatter.signed(row.amount, type: row.type))
                .font(.ledgerNumber(.callout, weight: .semibold))
                .foregroundStyle(row.type == .income ? Theme.positive : Theme.ink)
                .strikethrough(row.isDuplicate)
        }
        .padding(.vertical, 2)
        .opacity(row.isDuplicate ? 0.55 : 1)
    }
}
