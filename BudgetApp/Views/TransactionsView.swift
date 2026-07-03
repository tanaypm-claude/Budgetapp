import SwiftData
import SwiftUI

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]

    @State private var searchText = ""
    @State private var filters = TransactionFilters()
    @State private var showingFilters = false
    @State private var showingAddTransaction = false
    @State private var editingTransaction: BudgetTransaction?
    @State private var selection = Set<UUID>()
    @State private var selectionMode = false
    @State private var showingBulkMove = false
    @State private var bulkCategoryId: UUID?
    @State private var showingDeleteConfirmation = false

    private var filteredTransactions: [BudgetTransaction] {
        transactions.filter(matchesSearchAndFilters)
    }

    private var recurringSuggestions: [RecurringSuggestion] {
        RecurringDetector.suggestions(from: transactions)
    }

    var body: some View {
        List {
            if !recurringSuggestions.isEmpty && searchText.isEmpty && filters.isEmpty {
                Section("Possible Recurring") {
                    ForEach(recurringSuggestions.prefix(3)) { suggestion in
                        Button {
                            createRecurring(from: suggestion)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(suggestion.count) similar payments - \(suggestion.likelyFrequency.label)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(MoneyFormatter.string(suggestion.averageAmount))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }
            }

            Section {
                if filteredTransactions.isEmpty {
                    ContentUnavailableView("No Matching Transactions", systemImage: "magnifyingglass")
                } else {
                    ForEach(filteredTransactions) { transaction in
                        transactionRow(transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectionMode {
                                    toggleSelection(transaction.id)
                                } else {
                                    editingTransaction = transaction
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    selection = [transaction.id]
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    transaction.isReviewed.toggle()
                                    transaction.touch()
                                    try? modelContext.save()
                                } label: {
                                    Label(transaction.isReviewed ? "Unreview" : "Review", systemImage: transaction.isReviewed ? "eye.slash" : "checkmark.circle")
                                }
                                .tint(transaction.isReviewed ? .orange : .green)
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Transactions")
                    Spacer()
                    Text("\(filteredTransactions.count)")
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Ledger")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(selectionMode ? "Done" : "Select") {
                    selectionMode.toggle()
                    if !selectionMode {
                        selection.removeAll()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFilters = true
                } label: {
                    Label(filters.isEmpty ? "Filters" : "Filters \(filters.activeCount)", systemImage: filters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Label("Add Transaction", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selectionMode && !selection.isEmpty {
                bulkBar
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            NavigationStack {
                TransactionEditorView(transaction: nil)
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            NavigationStack {
                TransactionEditorView(transaction: transaction)
            }
        }
        .sheet(isPresented: $showingFilters) {
            NavigationStack {
                TransactionFiltersView(filters: $filters, categories: categories, accounts: accounts)
            }
        }
        .sheet(isPresented: $showingBulkMove) {
            NavigationStack {
                Form {
                    Picker("Category", selection: $bulkCategoryId) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(categories.filter(\.isActive)) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }
                .navigationTitle("Move \(selection.count) Item(s)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingBulkMove = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Move") {
                            bulkMove()
                        }
                    }
                }
            }
        }
        .confirmationDialog("Delete selected transactions?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteSelected()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone. Back up first if you are unsure.")
        }
    }

    private var bulkBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                showingBulkMove = true
            } label: {
                Label("Move", systemImage: "folder")
            }
            Button {
                markSelected(reviewed: true)
            } label: {
                Label("Review", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func transactionRow(_ transaction: BudgetTransaction) -> some View {
        HStack(spacing: 12) {
            if selectionMode {
                Image(systemName: selection.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.contains(transaction.id) ? BudgetTheme.teal : .secondary)
            }
            Image(systemName: transaction.type == .income ? "arrow.down.circle.fill" : transaction.type == .transfer ? "arrow.left.arrow.right.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(transaction.type == .income ? BudgetTheme.moss : transaction.type == .transfer ? BudgetTheme.teal : BudgetTheme.rust)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(transaction.merchant)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !transaction.isReviewed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Needs review")
                    }
                }
                HStack {
                    CategoryPill(category: categories.category(id: transaction.categoryId))
                    Text(accounts.account(id: transaction.accountId)?.name ?? "No account")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(MoneyFormatter.string(transaction.amount))
                    .font(.subheadline.monospacedDigit())
                    .privacySensitive()
                Text(AppDateFormatters.dayMonth.string(from: transaction.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(transactionAccessibilityLabel(transaction))
    }

    private func transactionAccessibilityLabel(_ transaction: BudgetTransaction) -> String {
        let category = categories.category(id: transaction.categoryId)?.name ?? "Unassigned"
        let account = accounts.account(id: transaction.accountId)?.name ?? "No account"
        let reviewState = transaction.isReviewed ? "Reviewed" : "Needs review"
        return "\(transaction.type.label), \(transaction.merchant), \(MoneyFormatter.string(transaction.amount)), \(category), \(account), \(AppDateFormatters.short.string(from: transaction.date)), \(reviewState)"
    }

    private func matchesSearchAndFilters(_ transaction: BudgetTransaction) -> Bool {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            let category = categories.category(id: transaction.categoryId)?.name.lowercased() ?? ""
            let account = accounts.account(id: transaction.accountId)?.name.lowercased() ?? ""
            let haystack = [transaction.merchant, transaction.narration, transaction.note, category, account].joined(separator: " ").lowercased()
            guard haystack.contains(query) else { return false }
        }

        if let categoryId = filters.categoryId, transaction.categoryId != categoryId { return false }
        if let accountId = filters.accountId, transaction.accountId != accountId { return false }
        if let type = filters.type, transaction.type != type { return false }
        if let source = filters.source, transaction.source != source { return false }
        if let start = filters.startDate, transaction.date < Calendar.current.startOfDay(for: start) { return false }
        if let end = filters.endDate {
            let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: end)) ?? end
            if transaction.date > endOfDay { return false }
        }
        return true
    }

    private func toggleSelection(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func bulkMove() {
        transactions.filter { selection.contains($0.id) }.forEach { transaction in
            transaction.categoryId = bulkCategoryId
            transaction.isReviewed = bulkCategoryId != nil
            transaction.touch()
        }
        try? modelContext.save()
        selection.removeAll()
        selectionMode = false
        showingBulkMove = false
    }

    private func markSelected(reviewed: Bool) {
        transactions.filter { selection.contains($0.id) }.forEach { transaction in
            transaction.isReviewed = reviewed
            transaction.touch()
        }
        try? modelContext.save()
        selection.removeAll()
        selectionMode = false
    }

    private func deleteSelected() {
        transactions.filter { selection.contains($0.id) }.forEach(modelContext.delete)
        try? modelContext.save()
        selection.removeAll()
        selectionMode = false
    }

    private func createRecurring(from suggestion: RecurringSuggestion) {
        guard let latest = transactions.first(where: { transaction in
            transaction.merchant
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) == suggestion.merchantKey
        }) else { return }

        let nextDate = Calendar.current.date(byAdding: .month, value: 1, to: latest.date) ?? Date()
        modelContext.insert(RecurringPayment(
            name: suggestion.displayName,
            amount: suggestion.averageAmount,
            categoryId: latest.categoryId,
            accountId: latest.accountId,
            frequency: suggestion.likelyFrequency,
            nextExpectedDate: nextDate
        ))
        try? modelContext.save()
    }
}
