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

    /// Rows that will actually be written: selected, not duplicate, and dated.
    private var selectedCount: Int { rows.filter { $0.isSelectedForImport && !$0.isDuplicate && $0.date != nil }.count }
    private var duplicateCount: Int { rows.filter(\.isDuplicate).count }
    private var reviewCount: Int { rows.filter { $0.isSelectedForImport && $0.needsReview && !$0.isDuplicate }.count }
    private var missingDateCount: Int { rows.filter { $0.isSelectedForImport && !$0.isDuplicate && $0.date == nil }.count }

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
            if missingDateCount > 0 {
                Label("\(missingDateCount) row(s) need a date before they can be saved.",
                      systemImage: "calendar.badge.exclamationmark")
                    .font(.ledgerCaption()).foregroundStyle(Theme.negative)
            }
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
                ImportPreviewRow(
                    row: $row,
                    categories: categories.filter(\.isActive),
                    accounts: accounts.filter(\.isActive)
                )
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

/// A single editable preview row: include toggle plus inline corrections for
/// date, type, category and account. Rows with issues are visually flagged and
/// undated rows can never be silently saved.
struct ImportPreviewRow: View {
    @Binding var row: ParsedTransaction
    let categories: [Category]
    let accounts: [Account]

    private var dateMissing: Bool { row.date == nil }
    private var willImport: Bool { row.isSelectedForImport && !row.isDuplicate && !dateMissing }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { row.date ?? Date() },
            set: { row.date = $0; recompute() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.md) {
                Button {
                    if !row.isDuplicate { row.isSelectedForImport.toggle(); Haptics.selection() }
                } label: {
                    Image(systemName: willImport ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(willImport ? Theme.positive : Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .disabled(row.isDuplicate)
                .accessibilityLabel(willImport ? "Included" : "Excluded")

                Text(row.displayName)
                    .font(.ledgerBody().weight(.medium))
                    .foregroundStyle(row.isDuplicate ? Theme.inkFaint : Theme.ink)
                    .lineLimit(1)
                Spacer()
                Text(CurrencyFormatter.signed(row.amount, type: row.type))
                    .font(.ledgerNumber(.callout, weight: .semibold))
                    .foregroundStyle(row.type == .income ? Theme.positive : Theme.ink)
                    .strikethrough(row.isDuplicate)
            }

            DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                .font(.ledgerCaption())

            Picker("Type", selection: $row.type) {
                ForEach(TransactionType.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Category", selection: $row.resolvedCategoryId) {
                Text("Needs review").tag(UUID?.none)
                ForEach(categories) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
            }
            .font(.ledgerCaption())

            Picker("Account", selection: $row.resolvedAccountId) {
                Text("Default").tag(UUID?.none)
                ForEach(accounts) { Label($0.name, systemImage: $0.type.symbolName).tag(Optional($0.id)) }
            }
            .font(.ledgerCaption())

            if dateMissing {
                Label("Date required — set a date to import this row", systemImage: "calendar.badge.exclamationmark")
                    .font(.ledgerCaption()).foregroundStyle(Theme.negative)
            } else if !row.issues.isEmpty {
                Label(row.issues.joined(separator: " · "),
                      systemImage: row.isDuplicate ? "doc.on.doc" : "exclamationmark.triangle")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(row.isDuplicate ? Theme.inkFaint : Theme.warning)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .opacity(row.isDuplicate ? 0.6 : 1)
        .overlay(alignment: .leading) {
            if (dateMissing || row.needsReview) && !row.isDuplicate {
                Rectangle().fill(dateMissing ? Theme.negative : Theme.warning).frame(width: 3)
            }
        }
        .onChange(of: row.resolvedCategoryId) { _, _ in recompute() }
    }

    /// Keep `issues` / `needsReview` in sync after inline edits so a corrected
    /// row is committed as reviewed (and an undated row stays flagged).
    private func recompute() {
        var issues = row.issues.filter { $0 != "No category — needs review" && $0 != "Unrecognised date" }
        if row.date == nil { issues.append("Unrecognised date") }
        if row.resolvedCategoryId == nil { issues.append("No category — needs review") }
        row.issues = issues
        row.needsReview = row.date == nil || row.resolvedCategoryId == nil
    }
}
