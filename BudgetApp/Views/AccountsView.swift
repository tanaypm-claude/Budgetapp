import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]

    @State private var editingAccount: BudgetAccount?
    @State private var showingAddAccount = false
    @State private var accountToArchive: BudgetAccount?

    var body: some View {
        List {
            Section("Accounts") {
                ForEach(accounts.filter(\.isActive)) { account in
                    Button {
                        editingAccount = account
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: account.type))
                                .foregroundStyle(BudgetTheme.teal)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.headline)
                                Text(account.type.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(MoneyFormatter.string(BudgetMath.accountBalance(account: account, transactions: transactions)))
                                    .font(.subheadline.monospacedDigit())
                                    .privacySensitive()
                                Text("Opening \(MoneyFormatter.string(account.openingBalance))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .privacySensitive()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            accountToArchive = account
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }

            let archived = accounts.filter { !$0.isActive }
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { account in
                        HStack {
                            Label(account.name, systemImage: icon(for: account.type))
                            Spacer()
                            Button("Restore") {
                                account.isActive = true
                                account.touch()
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAccount = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            NavigationStack {
                AccountEditorView(account: nil)
            }
        }
        .sheet(item: $editingAccount) { account in
            NavigationStack {
                AccountEditorView(account: account)
            }
        }
        .confirmationDialog("Archive account?", isPresented: Binding(
            get: { accountToArchive != nil },
            set: { if !$0 { accountToArchive = nil } }
        ), titleVisibility: .visible) {
            Button("Archive", role: .destructive) {
                accountToArchive?.isActive = false
                accountToArchive?.touch()
                try? modelContext.save()
                accountToArchive = nil
            }
            Button("Cancel", role: .cancel) { accountToArchive = nil }
        } message: {
            Text("Transactions stay linked, but this account will be hidden from active pickers.")
        }
    }

    private func icon(for type: AccountType) -> String {
        switch type {
        case .bank: "building.columns.fill"
        case .creditCard: "creditcard.fill"
        case .cash: "banknote.fill"
        case .wallet: "wallet.pass.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let account: BudgetAccount?
    @State private var name: String
    @State private var type: AccountType
    @State private var openingBalance: Decimal
    @State private var isActive: Bool

    init(account: BudgetAccount?) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .bank)
        _openingBalance = State(initialValue: account?.openingBalance ?? 0)
        _isActive = State(initialValue: account?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Account") {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
            }

            Section("Balance") {
                TextField("Opening balance", value: $openingBalance, format: .number)
                    .keyboardType(.decimalPad)
                Toggle("Active", isOn: $isActive)
            }
        }
        .navigationTitle(account == nil ? "New Account" : "Edit Account")
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
        if let account {
            account.name = trimmedName
            account.type = type
            account.openingBalance = openingBalance
            account.currentBalance = openingBalance
            account.isActive = isActive
            account.touch()
        } else {
            modelContext.insert(BudgetAccount(
                name: trimmedName,
                type: type,
                openingBalance: openingBalance,
                currentBalance: openingBalance,
                isActive: isActive
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
