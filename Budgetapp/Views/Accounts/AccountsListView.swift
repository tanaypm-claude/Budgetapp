import SwiftUI
import SwiftData

/// Lists accounts with live balances (opening balance + transactions).
struct AccountsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @State private var showingEditor = false

    private func liveBalance(_ account: Account) -> Decimal {
        BudgetCalculator.balance(accountId: account.id, openingBalance: account.openingBalance, transactions: transactions)
    }

    private var netWorth: Decimal {
        accounts.filter(\.isActive).reduce(Decimal(0)) { $0 + liveBalance($1) }
    }

    var body: some View {
        Group {
            if accounts.isEmpty {
                EmptyStateView(icon: "building.columns", title: "No accounts",
                               message: "Add bank accounts, cards, cash or wallets.",
                               actionTitle: "Add Account", action: { showingEditor = true })
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add account")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack { AccountEditorView(mode: .create, nextSortOrder: accounts.count) }
        }
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text("Net across accounts").font(.ledgerBody()).foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    Text(CurrencyFormatter.string(netWorth))
                        .font(.ledgerNumber(.title3, weight: .bold))
                        .foregroundStyle(netWorth < 0 ? Theme.negative : Theme.ink)
                }
                .listRowBackground(Theme.surfaceSunken)
            }
            Section {
                ForEach(accounts) { account in
                    NavigationLink {
                        AccountEditorView(mode: .edit(account), nextSortOrder: accounts.count)
                    } label: {
                        AccountRow(account: account, balance: liveBalance(account))
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }
}

struct AccountRow: View {
    let account: Account
    let balance: Decimal

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            CategoryGlyph(symbol: account.type.symbolName, colorHex: "#4C8CB5", size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name).font(.ledgerBody().weight(.medium)).foregroundStyle(Theme.ink)
                Text(account.isActive ? account.type.label : "Archived")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text(CurrencyFormatter.string(balance))
                .font(.ledgerNumber(.callout, weight: .semibold))
                .foregroundStyle(balance < 0 ? Theme.negative : Theme.ink)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.name), \(CurrencyFormatter.string(balance))")
    }
}

#Preview {
    NavigationStack { AccountsListView() }
        .modelContainer(PreviewData.container())
}
