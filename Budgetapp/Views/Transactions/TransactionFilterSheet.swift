import SwiftUI

/// Edits a copy of the active `TransactionFilter` and applies on Done.
struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: TransactionFilter
    let categories: [Category]
    let accounts: [Account]

    @State private var draft = TransactionFilter()

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Picker("Range", selection: $draft.dateRange) {
                        ForEach(TransactionFilter.DateRangeOption.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Type") {
                    Picker("Type", selection: $draft.type) {
                        Text("Any").tag(TransactionType?.none)
                        ForEach(TransactionType.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                    Picker("Source", selection: $draft.source) {
                        Text("Any").tag(TransactionSource?.none)
                        ForEach(TransactionSource.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                    Toggle("Only needs review", isOn: $draft.onlyNeedsReview)
                }
                Section("Category") {
                    Picker("Category", selection: $draft.categoryId) {
                        Text("Any").tag(UUID?.none)
                        ForEach(categories) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Section("Account") {
                    Picker("Account", selection: $draft.accountId) {
                        Text("Any").tag(UUID?.none)
                        ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { draft = TransactionFilter() }
                        .disabled(!draft.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { filter = draft; dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { draft = filter }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A simple category chooser used for bulk-move.
struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let onPick: (Category) -> Void

    var body: some View {
        NavigationStack {
            List(categories.filter(\.isActive)) { category in
                Button {
                    onPick(category)
                    dismiss()
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        CategoryGlyph(symbol: category.symbol, colorHex: category.colorHex, size: 32)
                        Text(category.name).foregroundStyle(Theme.ink)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
