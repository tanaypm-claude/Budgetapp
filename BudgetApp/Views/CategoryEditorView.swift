import SwiftData
import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: BudgetCategory?
    let nextSortOrder: Int

    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String
    @State private var monthlyBudget: Decimal
    @State private var isActive: Bool

    private let swatches = ["#0E0B09", "#750609", "#F7EFE2"]

    init(category: BudgetCategory?, nextSortOrder: Int) {
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.symbol ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#750609")
        _monthlyBudget = State(initialValue: category?.monthlyBudget ?? 0)
        _isActive = State(initialValue: category?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name)
                TextField("SF Symbol", text: $symbol)
                    .textInputAutocapitalization(.never)
                HStack {
                    Image(systemName: symbol.isEmpty ? "tag.fill" : symbol)
                        .foregroundStyle(colorHex == "#F7EFE2" ? BudgetTheme.ink : Color(hex: colorHex))
                        .frame(width: 30)
                    Text(name.isEmpty ? "Preview" : name)
                        .font(.headline)
                }
            }

            Section("Budget") {
                HStack {
                    Text("Monthly")
                    Spacer()
                    TextField("0", value: $monthlyBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(swatches, id: \.self) { swatch in
                        Button {
                            colorHex = swatch
                        } label: {
                            Circle()
                                .fill(Color(hex: swatch))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if colorHex == swatch {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(swatch == "#F7EFE2" ? BudgetTheme.ink : .white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use color \(swatch)")
                    }
                }
            }

            Section {
                Toggle("Active", isOn: $isActive)
            }
        }
        .navigationTitle(category == nil ? "New Category" : "Edit Category")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            category.name = trimmedName
            category.symbol = symbol.isEmpty ? "tag.fill" : symbol
            category.colorHex = colorHex
            category.monthlyBudget = max(.zero, monthlyBudget)
            category.isActive = isActive
            category.touch()
        } else {
            modelContext.insert(BudgetCategory(
                name: trimmedName,
                symbol: symbol.isEmpty ? "tag.fill" : symbol,
                colorHex: colorHex,
                monthlyBudget: max(.zero, monthlyBudget),
                sortOrder: nextSortOrder,
                isActive: isActive
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
