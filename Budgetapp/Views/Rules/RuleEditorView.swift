import SwiftUI
import SwiftData

struct RuleEditorView: View {
    enum Mode {
        case create
        case edit(ImportRule)
        case createFrom(merchant: String, description: String, categoryId: UUID?, accountId: UUID?)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let mode: Mode

    @State private var name = ""
    @State private var matchField: RuleMatchField = .merchant
    @State private var matchType: RuleMatchType = .contains
    @State private var matchValue = ""
    @State private var categoryId: UUID? = nil
    @State private var accountId: UUID? = nil
    @State private var priorityString = "100"
    @State private var isActive = true
    @State private var didLoad = false
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool {
        !matchValue.trimmingCharacters(in: .whitespaces).isEmpty && categoryId != nil
    }

    var body: some View {
        Form {
            Section("When a transaction's…") {
                Picker("Field", selection: $matchField) {
                    ForEach(RuleMatchField.allCases) { Text($0.label).tag($0) }
                }
                Picker("Condition", selection: $matchType) {
                    ForEach(RuleMatchType.allCases) { Text($0.label).tag($0) }
                }
                TextField(matchType == .regex ? "Pattern" : "Value (e.g. Swiggy)", text: $matchValue)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(matchType == .regex ? .never : .words)
            }

            Section("Then set") {
                Picker("Category", selection: $categoryId) {
                    Text("Choose…").tag(UUID?.none)
                    ForEach(categories.filter(\.isActive)) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
                }
                Picker("Account (optional)", selection: $accountId) {
                    Text("Don't change").tag(UUID?.none)
                    ForEach(accounts.filter(\.isActive)) { Label($0.name, systemImage: $0.type.symbolName).tag(Optional($0.id)) }
                }
            }

            Section("Options") {
                HStack {
                    Text("Priority")
                    Spacer()
                    TextField("100", text: $priorityString)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                }
                Toggle("Active", isOn: $isActive)
            } footer: {
                Text("Lower priority numbers are evaluated first.")
            }

            Section {
                Text(previewText).font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
            }

            if isEditing {
                Section {
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete rule", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(isEditing ? "Edit Rule" : "New Rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
        }
        .confirmationDialog("Delete this rule?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteRule() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: loadIfNeeded)
    }

    private var previewText: String {
        let category = categories.first { $0.id == categoryId }?.name ?? "a category"
        let value = matchValue.isEmpty ? "…" : matchValue
        return "If \(matchField.label.lowercased()) \(matchType.label.lowercased()) “\(value)”, categorise as \(category)."
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        switch mode {
        case .create:
            break
        case let .edit(rule):
            name = rule.name
            matchField = rule.matchField
            matchType = rule.matchType
            matchValue = rule.matchValue
            categoryId = rule.categoryId
            accountId = rule.accountId
            priorityString = String(rule.priority)
            isActive = rule.isActive
        case let .createFrom(merchant, description, category, account):
            let useMerchant = !merchant.trimmingCharacters(in: .whitespaces).isEmpty
            matchField = useMerchant ? .merchant : .description
            matchValue = useMerchant ? merchant : description
            categoryId = category
            accountId = account
            name = matchValue
        }
    }

    private func save() {
        let priority = Int(priorityString.trimmingCharacters(in: .whitespaces)) ?? 100
        let resolvedName = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? matchValue.trimmingCharacters(in: .whitespaces) : name.trimmingCharacters(in: .whitespaces)
        if case let .edit(rule) = mode {
            rule.name = resolvedName
            rule.matchField = matchField
            rule.matchType = matchType
            rule.matchValue = matchValue.trimmingCharacters(in: .whitespaces)
            rule.categoryId = categoryId
            rule.accountId = accountId
            rule.priority = priority
            rule.isActive = isActive
            rule.touch()
        } else {
            let rule = ImportRule(name: resolvedName, matchField: matchField, matchType: matchType,
                                  matchValue: matchValue.trimmingCharacters(in: .whitespaces),
                                  categoryId: categoryId, accountId: accountId, priority: priority, isActive: isActive)
            context.insert(rule)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func deleteRule() {
        if case let .edit(rule) = mode {
            context.delete(rule); try? context.save(); Haptics.warning(); dismiss()
        }
    }
}
