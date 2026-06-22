import SwiftUI
import SwiftData

struct AccountEditorView: View {
    enum Mode { case create, edit(Account) }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]

    let mode: Mode
    let nextSortOrder: Int

    @State private var name = ""
    @State private var type: AccountType = .bank
    @State private var openingBalanceString = ""
    @State private var isActive = true
    @State private var didLoad = false
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var liveBalance: Decimal? {
        guard case let .edit(account) = mode else { return nil }
        let opening = ValueParsing.parseAmount(openingBalanceString) ?? 0
        return BudgetCalculator.balance(accountId: account.id, openingBalance: opening, transactions: transactions)
    }

    var body: some View {
        Form {
            Section {
                TextField("Account name", text: $name).textInputAutocapitalization(.words)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { Label($0.label, systemImage: $0.symbolName).tag($0) }
                }
            }

            Section("Opening balance") {
                HStack {
                    Text(AppSettings.currencySymbol).foregroundStyle(Theme.inkSecondary)
                    TextField("0", text: $openingBalanceString)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.ledgerNumber(.title3, weight: .semibold))
                }
            } footer: {
                Text("For credit cards, enter the current outstanding as a negative number, e.g. −12000.")
            }

            if let liveBalance {
                Section("Current balance") {
                    HStack {
                        Text("Computed from transactions").font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                        Spacer()
                        Text(CurrencyFormatter.string(liveBalance))
                            .font(.ledgerNumber(.body, weight: .semibold))
                            .foregroundStyle(liveBalance < 0 ? Theme.negative : Theme.ink)
                    }
                }
            }

            if isEditing {
                Section {
                    Toggle("Active", isOn: $isActive)
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete account", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Deleting leaves its transactions in place but unlinked. Set inactive to hide it instead.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(isEditing ? "Edit Account" : "New Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
            if !isEditing { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .confirmationDialog("Delete this account?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if case let .edit(account) = mode {
            name = account.name
            type = account.type
            openingBalanceString = NSDecimalNumber(decimal: account.openingBalance).stringValue
            isActive = account.isActive
        }
    }

    private func save() {
        let opening = ValueParsing.parseAmount(openingBalanceString) ?? 0
        switch mode {
        case .create:
            let account = Account(name: name.trimmed, type: type, openingBalance: opening,
                                  currentBalance: opening, sortOrder: nextSortOrder)
            context.insert(account)
        case let .edit(account):
            account.name = name.trimmed
            account.type = type
            account.openingBalance = opening
            account.isActive = isActive
            account.touch()
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func deleteAccount() {
        if case let .edit(account) = mode {
            context.delete(account)
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
    NavigationStack { AccountEditorView(mode: .create, nextSortOrder: 0) }
        .modelContainer(PreviewData.container())
}
