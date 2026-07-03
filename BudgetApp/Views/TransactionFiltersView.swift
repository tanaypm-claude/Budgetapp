import SwiftUI

struct TransactionFilters: Equatable {
    var categoryId: UUID?
    var accountId: UUID?
    var type: TransactionType?
    var source: TransactionSource?
    var startDate: Date?
    var endDate: Date?

    var isEmpty: Bool {
        categoryId == nil && accountId == nil && type == nil && source == nil && startDate == nil && endDate == nil
    }

    var activeCount: Int {
        [categoryId != nil, accountId != nil, type != nil, source != nil, startDate != nil, endDate != nil].filter { $0 }.count
    }
}

struct TransactionFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filters: TransactionFilters
    let categories: [BudgetCategory]
    let accounts: [BudgetAccount]

    @State private var usesStartDate: Bool
    @State private var usesEndDate: Bool
    @State private var startDate: Date
    @State private var endDate: Date

    init(filters: Binding<TransactionFilters>, categories: [BudgetCategory], accounts: [BudgetAccount]) {
        _filters = filters
        self.categories = categories
        self.accounts = accounts
        _usesStartDate = State(initialValue: filters.wrappedValue.startDate != nil)
        _usesEndDate = State(initialValue: filters.wrappedValue.endDate != nil)
        _startDate = State(initialValue: filters.wrappedValue.startDate ?? Date())
        _endDate = State(initialValue: filters.wrappedValue.endDate ?? Date())
    }

    var body: some View {
        Form {
            Section("Classification") {
                Picker("Category", selection: $filters.categoryId) {
                    Text("Any").tag(UUID?.none)
                    ForEach(categories.filter(\.isActive)) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }

                Picker("Account", selection: $filters.accountId) {
                    Text("Any").tag(UUID?.none)
                    ForEach(accounts.filter(\.isActive)) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
            }

            Section("Kind") {
                Picker("Type", selection: $filters.type) {
                    Text("Any").tag(TransactionType?.none)
                    ForEach(TransactionType.allCases) { type in
                        Text(type.label).tag(Optional(type))
                    }
                }

                Picker("Source", selection: $filters.source) {
                    Text("Any").tag(TransactionSource?.none)
                    ForEach(TransactionSource.allCases) { source in
                        Text(source.label).tag(Optional(source))
                    }
                }
            }

            Section("Dates") {
                Toggle("From date", isOn: $usesStartDate)
                if usesStartDate {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                }
                Toggle("To date", isOn: $usesEndDate)
                if usesEndDate {
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }
            }
        }
        .navigationTitle("Filters")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") {
                    filters = TransactionFilters()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    filters.startDate = usesStartDate ? startDate : nil
                    filters.endDate = usesEndDate ? endDate : nil
                    dismiss()
                }
            }
        }
    }
}
