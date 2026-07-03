import SwiftData
import SwiftUI

struct RulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImportRule.priority) private var rules: [ImportRule]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    @State private var showingAddRule = false
    @State private var editingRule: ImportRule?

    var body: some View {
        List {
            Section("Priority Order") {
                if rules.isEmpty {
                    ContentUnavailableView("No Smart Rules", systemImage: "wand.and.stars", description: Text("Assign + Teach in Import, or add a rule here."))
                } else {
                    ForEach(rules) { rule in
                        Button {
                            editingRule = rule
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(rule.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("#\(rule.priority)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(rule.matchField.label) \(rule.matchType.label.lowercased()) \"\(rule.matchValue)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    CategoryPill(category: categories.category(id: rule.categoryId))
                                    if !rule.isActive {
                                        Text("Inactive")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(rule)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Smart Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRule = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            NavigationStack {
                RuleEditorView(rule: nil, nextPriority: (rules.map(\.priority).max() ?? 0) + 10)
            }
        }
        .sheet(item: $editingRule) { rule in
            NavigationStack {
                RuleEditorView(rule: rule, nextPriority: rule.priority)
            }
        }
    }
}

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]

    let rule: ImportRule?
    let nextPriority: Int

    @State private var name: String
    @State private var matchField: RuleMatchField
    @State private var matchType: RuleMatchType
    @State private var matchValue: String
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var priority: Int
    @State private var isActive: Bool

    init(rule: ImportRule?, nextPriority: Int) {
        self.rule = rule
        self.nextPriority = nextPriority
        _name = State(initialValue: rule?.name ?? "")
        _matchField = State(initialValue: rule?.matchField ?? .merchant)
        _matchType = State(initialValue: rule?.matchType ?? .contains)
        _matchValue = State(initialValue: rule?.matchValue ?? "")
        _categoryId = State(initialValue: rule?.categoryId)
        _accountId = State(initialValue: rule?.accountId)
        _priority = State(initialValue: rule?.priority ?? nextPriority)
        _isActive = State(initialValue: rule?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Rule") {
                TextField("Name", text: $name)
                Picker("Field", selection: $matchField) {
                    ForEach(RuleMatchField.allCases) { field in
                        Text(field.label).tag(field)
                    }
                }
                Picker("Match", selection: $matchType) {
                    ForEach(RuleMatchType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                TextField("Value", text: $matchValue)
                    .textInputAutocapitalization(.never)
            }

            Section("Apply") {
                Picker("Category", selection: $categoryId) {
                    Text("No change").tag(UUID?.none)
                    ForEach(categories.filter(\.isActive)) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                Picker("Account", selection: $accountId) {
                    Text("No change").tag(UUID?.none)
                    ForEach(accounts.filter(\.isActive)) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                Stepper("Priority \(priority)", value: $priority, in: 1...999)
                Toggle("Active", isOn: $isActive)
            }
        }
        .navigationTitle(rule == nil ? "New Rule" : "Edit Rule")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(matchValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || categoryId == nil)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = matchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rule {
            rule.name = cleanName.isEmpty ? "\(matchField.label) rule" : cleanName
            rule.matchField = matchField
            rule.matchType = matchType
            rule.matchValue = cleanValue
            rule.categoryId = categoryId
            rule.accountId = accountId
            rule.priority = priority
            rule.isActive = isActive
            rule.touch()
        } else {
            modelContext.insert(ImportRule(
                name: cleanName.isEmpty ? "\(matchField.label) rule" : cleanName,
                matchField: matchField,
                matchType: matchType,
                matchValue: cleanValue,
                categoryId: categoryId,
                accountId: accountId,
                priority: priority,
                isActive: isActive
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
