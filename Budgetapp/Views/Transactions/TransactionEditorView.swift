import SwiftUI
import SwiftData

/// Create or edit a single transaction. Also offers "create a rule from this"
/// so a categorised transaction can teach the import engine.
struct TransactionEditorView: View {
    enum Mode {
        case create
        case edit(Transaction)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Project.name) private var projects: [Project]

    let mode: Mode

    // Editable fields
    @State private var date = Date.now
    @State private var merchant = ""
    @State private var narration = ""
    @State private var amountString = ""
    @State private var type: TransactionType = .expense
    @State private var categoryId: UUID? = nil
    @State private var accountId: UUID? = nil
    @State private var projectId: UUID? = nil
    @State private var note = ""
    @State private var isReviewed = true

    @State private var showingRuleEditor = false
    @State private var showingDeleteConfirm = false
    @State private var didLoad = false

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }

    private var amountValue: Decimal? { ValueParsing.parseAmount(amountString) }
    private var canSave: Bool {
        guard let value = amountValue, value > 0 else { return false }
        return !(merchant.trimmingCharacters(in: .whitespaces).isEmpty
                 && narration.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        Form {
            Section {
                TextField("Merchant", text: $merchant)
                    .textInputAutocapitalization(.words)
                TextField("Description / narration", text: $narration, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section {
                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(AppSettings.currencySymbol)
                        .foregroundStyle(Theme.inkSecondary)
                    TextField("0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .font(.ledgerNumber(.title3, weight: .semibold))
                }

                DatePicker("Date", selection: $date, displayedComponents: .date)
            }

            Section("Classification") {
                Picker("Category", selection: $categoryId) {
                    Text("Uncategorised").tag(UUID?.none)
                    ForEach(categories.filter(\.isActive)) { category in
                        Label(category.name, systemImage: category.symbol).tag(Optional(category.id))
                    }
                }
                Picker("Account", selection: $accountId) {
                    Text("None").tag(UUID?.none)
                    ForEach(accounts.filter(\.isActive)) { account in
                        Label(account.name, systemImage: account.type.symbolName).tag(Optional(account.id))
                    }
                }
                if !projects.isEmpty {
                    Picker("Project", selection: $projectId) {
                        Text("None").tag(UUID?.none)
                        ForEach(projects.filter(\.isActive)) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                }
                Toggle("Reviewed", isOn: $isReviewed)
            }

            Section("Note") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }

            if canSave {
                Section {
                    Button {
                        showingRuleEditor = true
                    } label: {
                        Label("Create import rule from this", systemImage: "wand.and.stars")
                    }
                }
            }

            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete transaction", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(isEditing ? "Edit" : "New Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingRuleEditor) {
            NavigationStack {
                RuleEditorView(mode: .createFrom(merchant: merchant, description: narration, categoryId: categoryId, accountId: accountId))
            }
        }
        .confirmationDialog("Delete this transaction?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteTransaction() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: Load / Save

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if case let .edit(txn) = mode {
            date = txn.date
            merchant = txn.merchant
            narration = txn.narration
            amountString = NSDecimalNumber(decimal: txn.magnitude).stringValue
            type = txn.type
            categoryId = txn.categoryId
            accountId = txn.accountId
            projectId = txn.projectId
            note = txn.note
            isReviewed = txn.isReviewed
        } else {
            accountId = accounts.first(where: \.isActive)?.id
        }
    }

    private func save() {
        guard let value = amountValue else { return }
        switch mode {
        case .create:
            let txn = Transaction(
                date: date, merchant: merchant.trimmed, narration: narration.trimmed,
                amount: value, type: type, categoryId: categoryId, accountId: accountId,
                projectId: projectId, source: .manual, note: note.trimmed, isReviewed: isReviewed
            )
            context.insert(txn)
        case let .edit(txn):
            txn.date = date
            txn.merchant = merchant.trimmed
            txn.narration = narration.trimmed
            txn.amount = value
            txn.type = type
            txn.categoryId = categoryId
            txn.accountId = accountId
            txn.projectId = projectId
            txn.note = note.trimmed
            txn.isReviewed = isReviewed
            txn.touch()
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func deleteTransaction() {
        if case let .edit(txn) = mode {
            context.delete(txn)
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
    NavigationStack {
        TransactionEditorView(mode: .create)
    }
    .modelContainer(PreviewData.container())
}
