import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    enum Mode { case create, edit(Category) }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let nextSortOrder: Int

    @State private var name = ""
    @State private var symbol = "tag"
    @State private var colorHex = CategoryPalette.colors.first ?? "#C97C3C"
    @State private var budgetString = ""
    @State private var didLoad = false
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section {
                HStack {
                    CategoryGlyph(symbol: symbol, colorHex: colorHex, size: 52)
                    TextField("Category name", text: $name)
                        .font(.ledgerHeadline())
                        .textInputAutocapitalization(.words)
                }
            }

            Section("Monthly budget") {
                HStack {
                    Text(AppSettings.currencySymbol).foregroundStyle(Theme.inkSecondary)
                    TextField("0", text: $budgetString)
                        .keyboardType(.decimalPad)
                        .font(.ledgerNumber(.title3, weight: .semibold))
                }
            }

            Section("Colour") {
                ColorSwatchPicker(selection: $colorHex)
            }

            Section("Icon") {
                SymbolPicker(selection: $symbol, colorHex: colorHex)
            }

            if isEditing {
                Section {
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete category", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Deleting keeps existing transactions but leaves them uncategorised. Archive instead to hide it without affecting history.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(isEditing ? "Edit Category" : "New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
            if !isEditing {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
        .confirmationDialog("Delete this category?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteCategory() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if case let .edit(category) = mode {
            name = category.name
            symbol = category.symbol
            colorHex = category.colorHex
            budgetString = category.monthlyBudget > 0 ? NSDecimalNumber(decimal: category.monthlyBudget).stringValue : ""
        }
    }

    private func save() {
        let budget = ValueParsing.parseAmount(budgetString) ?? 0
        switch mode {
        case .create:
            let category = Category(name: name.trimmed, symbol: symbol, colorHex: colorHex,
                                    monthlyBudget: budget, sortOrder: nextSortOrder)
            context.insert(category)
        case let .edit(category):
            category.name = name.trimmed
            category.symbol = symbol
            category.colorHex = colorHex
            category.monthlyBudget = budget
            category.touch()
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func deleteCategory() {
        if case let .edit(category) = mode {
            context.delete(category)
            try? context.save()
            Haptics.warning()
            dismiss()
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    NavigationStack { CategoryEditorView(mode: .create, nextSortOrder: 0) }
        .modelContainer(PreviewData.container())
}
