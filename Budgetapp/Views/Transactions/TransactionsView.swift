import SwiftUI
import SwiftData

/// The full ledger: searchable, filterable, with swipe actions and a bulk-edit
/// mode for moving/marking many transactions at once.
struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var searchText = ""
    @State private var filter = TransactionFilter()
    @State private var showingFilter = false
    @State private var showingEditor = false
    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    @State private var showingBulkCategoryPicker = false
    @State private var transactionToDelete: Transaction?
    @State private var showingBulkDeleteConfirm = false

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }

    private var filtered: [Transaction] {
        filter.apply(to: transactions, searchText: searchText)
    }

    /// Group filtered transactions by day for sectioned display.
    private struct DayGroup: Identifiable {
        let date: Date
        let items: [Transaction]
        var id: Date { date }
    }
    private var grouped: [DayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            DayGroup(date: day, items: groups[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: transactions.isEmpty ? "No transactions" : "Nothing matches",
                        message: transactions.isEmpty
                            ? "Add a transaction or import a statement."
                            : "Try clearing search or filters."
                    )
                } else {
                    transactionList
                }
            }
            .background(Theme.paper)
            .navigationTitle("Ledger")
            .searchable(text: $searchText, prompt: "Search merchant, note…")
            .toolbar { toolbarContent }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showingFilter) {
                TransactionFilterSheet(filter: $filter, categories: categories, accounts: accounts)
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack { TransactionEditorView(mode: .create) }
            }
            .sheet(isPresented: $showingBulkCategoryPicker) {
                CategoryPickerSheet(categories: categories) { category in
                    bulkMove(to: category)
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: Binding(
                get: { transactionToDelete != nil }, set: { if !$0 { transactionToDelete = nil } }
            ), titleVisibility: .visible, presenting: transactionToDelete) { txn in
                Button("Delete", role: .destructive) { delete(txn) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete \(selection.count) transaction(s)?", isPresented: $showingBulkDeleteConfirm, titleVisibility: .visible) {
                Button("Delete \(selection.count)", role: .destructive) { bulkDelete() }
                Button("Cancel", role: .cancel) {}
            }
            .safeAreaInset(edge: .bottom) {
                if editMode == .active && !selection.isEmpty {
                    bulkActionBar
                }
            }
        }
    }

    private var transactionList: some View {
        List(selection: $selection) {
            ForEach(grouped) { group in
                Section {
                    ForEach(group.items) { txn in
                        row(for: txn)
                    }
                } header: {
                    HStack {
                        Text(group.date.friendlyDay)
                        Spacer()
                        Text(CurrencyFormatter.compact(dayTotal(group.items)))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .font(.ledgerCaption().weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    @ViewBuilder
    private func row(for txn: Transaction) -> some View {
        Group {
            if editMode == .active {
                TransactionRow(transaction: txn, lookups: lookups)
            } else {
                NavigationLink {
                    TransactionEditorView(mode: .edit(txn))
                } label: {
                    TransactionRow(transaction: txn, lookups: lookups)
                }
            }
        }
        .listRowBackground(Theme.paper)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { transactionToDelete = txn } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                txn.isReviewed.toggle(); txn.touch(); save()
                Haptics.selection()
            } label: {
                Label(txn.isReviewed ? "Unreview" : "Reviewed",
                      systemImage: txn.isReviewed ? "circle" : "checkmark.circle")
            }
            .tint(Theme.positive)
        }
    }

    private var bulkActionBar: some View {
        HStack(spacing: Theme.Space.lg) {
            Text("\(selection.count) selected")
                .font(.ledgerCaption().weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Button {
                showingBulkCategoryPicker = true
            } label: { Label("Move", systemImage: "folder") }
            Button {
                bulkMarkReviewed()
            } label: { Label("Reviewed", systemImage: "checkmark.circle") }
            Button(role: .destructive) {
                showingBulkDeleteConfirm = true
            } label: { Label("Delete", systemImage: "trash") }
        }
        .font(.ledgerCaption())
        .padding(Theme.Space.md)
        .background(.bar)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.hairline), alignment: .top)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            EditButton()
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingFilter = true
            } label: {
                Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filter")

            Button {
                showingEditor = true
            } label: { Image(systemName: "plus") }
            .accessibilityLabel("Add transaction")
        }
    }

    // MARK: Actions

    private func dayTotal(_ items: [Transaction]) -> Decimal {
        items.reduce(Decimal(0)) { $0 + $1.signedBalanceEffect }
    }

    private func delete(_ txn: Transaction) {
        context.delete(txn)
        save()
        Haptics.tap()
    }

    private func bulkMove(to category: Category) {
        for txn in transactions where selection.contains(txn.id) {
            txn.categoryId = category.id
            txn.touch()
        }
        save()
        endEditing()
        Haptics.success()
    }

    private func bulkMarkReviewed() {
        for txn in transactions where selection.contains(txn.id) {
            txn.isReviewed = true
            txn.touch()
        }
        save()
        endEditing()
        Haptics.success()
    }

    private func bulkDelete() {
        for txn in transactions where selection.contains(txn.id) {
            context.delete(txn)
        }
        save()
        endEditing()
        Haptics.warning()
    }

    private func endEditing() {
        selection.removeAll()
        editMode = .inactive
    }

    private func save() { try? context.save() }
}

#Preview {
    TransactionsView()
        .modelContainer(PreviewData.container())
}
