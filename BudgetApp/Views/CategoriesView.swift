import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \RecurringPayment.nextExpectedDate) private var recurringPayments: [RecurringPayment]

    @State private var editingCategory: BudgetCategory?
    @State private var showingAddCategory = false
    @State private var showingBudgetModifier = false
    @State private var categoryToArchive: BudgetCategory?

    private var rows: [CategorySpendRow] {
        BudgetMath.categoryRows(transactions: transactions, categories: categories)
    }

    private var overview: BudgetOverview {
        BudgetMath.overview(transactions: transactions, categories: categories)
    }

    private var activeRows: [CategorySpendRow] {
        rows.filter { $0.category.isActive }
    }

    private var topRows: [CategorySpendRow] {
        activeRows
            .filter { $0.spent > .zero || $0.budget > .zero }
            .sorted { $0.spent > $1.spent }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        List {
            Section {
                categoryReportHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section {
                categorySignals
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(activeRows) { row in
                    Button {
                        editingCategory = row.category
                    } label: {
                        categoryRow(row)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            categoryToArchive = row.category
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
                .onMove(perform: moveCategories)
            } header: {
                Text("Monthly Categories")
            }

            Section {
                ForEach(transactions.prefix(5)) { transaction in
                    ledgerRow(transaction)
                }
                NavigationLink {
                    TransactionsView()
                } label: {
                    Label("Open full ledger", systemImage: "arrow.up.right.circle.fill")
                }
            } header: {
                Text("Ledger")
            }

            let archived = categories.filter { !$0.isActive }
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { category in
                        HStack {
                            Label(category.name, systemImage: category.symbol)
                            Spacer()
                            Button("Restore") {
                                category.isActive = true
                                category.touch()
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingBudgetModifier = true
                } label: {
                    Label("Modify Budgets", systemImage: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                CategoryEditorView(category: nil, nextSortOrder: categories.count)
            }
        }
        .sheet(isPresented: $showingBudgetModifier) {
            NavigationStack {
                BudgetModifierView(categories: categories.filter(\.isActive))
            }
        }
        .sheet(item: $editingCategory) { category in
            NavigationStack {
                CategoryEditorView(category: category, nextSortOrder: categories.count)
            }
        }
        .confirmationDialog("Archive category?", isPresented: Binding(
            get: { categoryToArchive != nil },
            set: { if !$0 { categoryToArchive = nil } }
        ), titleVisibility: .visible) {
            Button("Archive", role: .destructive) {
                categoryToArchive?.isActive = false
                categoryToArchive?.touch()
                try? modelContext.save()
                categoryToArchive = nil
            }
            Button("Cancel", role: .cancel) {
                categoryToArchive = nil
            }
        } message: {
            Text("Existing transactions stay linked. The category will stop appearing as an active budget line.")
        }
    }

    private var categoryReportHeader: some View {
        LedgerPanel(title: nil, subtitle: nil) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    DonutChart(slices: categorySlices, lineWidth: 22)
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category split")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BudgetTheme.ink)
                        Text(topRows.first?.category.name ?? "No movement yet")
                            .font(.subheadline)
                            .foregroundStyle(BudgetTheme.secondaryInk)
                        Text("\(Int(overview.percentUsed * 100))% of plan used")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(BudgetTheme.secondaryInk)
                    }
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatInstrument(
                            title: "Spent",
                            value: MoneyFormatter.string(overview.spent),
                            footnote: "Across active categories",
                            symbol: "💵",
                            percent: overview.percentUsed,
                            tint: BudgetTheme.stressTint(overview.percentUsed),
                            usesStressGradient: true
                        )
                        StatInstrument(
                            title: "Left",
                            value: MoneyFormatter.string(max(.zero, overview.remaining)),
                            footnote: "\(overview.daysLeft) day(s) left",
                            symbol: "👛",
                            percent: remainingPercent,
                            tint: overview.remaining < .zero ? BudgetTheme.red : BudgetTheme.green,
                            inverse: true,
                            usesStressGradient: true
                        )
                        NavigationLink {
                            ReportsView()
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("↗")
                                    .font(.largeTitle.weight(.black))
                                Text("Reports")
                                    .font(.headline)
                                Text("Outliers, rhythm and savings pressure")
                                    .font(.caption)
                                    .foregroundStyle(BudgetTheme.secondaryInk)
                            }
                            .foregroundStyle(BudgetTheme.ink)
                            .padding(16)
                            .frame(width: 220, height: 142, alignment: .leading)
                            .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categorySignals: some View {
        LedgerPanel(title: "Signals", subtitle: "Highest spend, strongest save, recurring pressure") {
            VStack(spacing: 12) {
                if activeRows.isEmpty {
                    ContentUnavailableView("No Category Signals", systemImage: "dial.low")
                        .frame(minHeight: 110)
                } else {
                    if let high = topRows.first {
                        signalRow(symbol: high.category.symbol, tint: BudgetTheme.red, title: "Highest spend", detail: "\(high.category.name) at \(MoneyFormatter.string(high.spent))")
                    }
                    if let saved = mostSavedRow {
                        signalRow(symbol: "sparkles", tint: BudgetTheme.green, title: "Most room", detail: "\(saved.category.name) has \(MoneyFormatter.string(max(.zero, saved.remaining))) left")
                    }
                    if let soon = recurringPayments.filter(\.isActive).first {
                        signalRow(symbol: "timer", tint: BudgetTheme.yellow, title: "Timer", detail: "\(soon.name) due \(AppDateFormatters.dayMonth.string(from: soon.nextExpectedDate))")
                    }
                    signalRow(symbol: "repeat", tint: BudgetTheme.blue, title: "Recurring total", detail: MoneyFormatter.string(recurringPayments.filter(\.isActive).reduce(.zero) { $0 + $1.amount }))
                }
            }
        }
    }

    private func categoryRow(_ row: CategorySpendRow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: row.category.symbol)
                    .foregroundStyle(barTint(for: row))
                    .frame(width: 38, height: 38)
                    .background(barTint(for: row).opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.category.name)
                        .font(.headline)
                        .foregroundStyle(BudgetTheme.ink)
                    Text(row.remaining >= .zero ? "\(MoneyFormatter.string(row.remaining)) left" : "\(MoneyFormatter.string(row.remaining.absoluteValue)) over")
                        .font(.caption)
                        .foregroundStyle(BudgetTheme.secondaryInk)
                        .privacySensitive()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(MoneyFormatter.string(row.spent))
                        .font(.subheadline.monospacedDigit())
                        .privacySensitive()
                    Text("of \(MoneyFormatter.string(row.budget))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                }
            }
            InstrumentBar(percent: min(1.25, row.percentUsed), tint: nil)
            HStack {
                Text(row.isOverBudget ? "Needs correction" : row.isCloseToBudget ? "Watch this" : "Inside plan")
                    .font(.caption)
                    .foregroundStyle(BudgetTheme.secondaryInk)
                Spacer()
                Text("\(Int(row.percentUsed * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func ledgerRow(_ transaction: BudgetTransaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type == .income ? "arrow.down.circle.fill" : transaction.type == .transfer ? "arrow.left.arrow.right.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(transaction.type == .income ? BudgetTheme.green : transaction.type == .transfer ? BudgetTheme.blue : BudgetTheme.red)
                .frame(width: 34, height: 34)
                .background((transaction.type == .income ? BudgetTheme.green : BudgetTheme.red).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BudgetTheme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    CategoryPill(category: categories.category(id: transaction.categoryId))
                    if !transaction.isReviewed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(BudgetTheme.yellow)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(MoneyFormatter.string(transaction.amount))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(BudgetTheme.ink)
                    .privacySensitive()
                Text(AppDateFormatters.dayMonth.string(from: transaction.date))
                    .font(.caption2)
                    .foregroundStyle(BudgetTheme.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func signalRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BudgetTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(BudgetTheme.secondaryInk)
                    .privacySensitive()
            }
            Spacer()
        }
    }

    private var categorySlices: [DonutSlice] {
        let palette = [BudgetTheme.blue, BudgetTheme.green, BudgetTheme.yellow, BudgetTheme.red, BudgetTheme.lightBlue]
        return Array(topRows.enumerated()).map { index, row in
            DonutSlice(value: row.spent, color: palette[index % palette.count])
        }
    }

    private var mostSavedRow: CategorySpendRow? {
        activeRows
            .filter { $0.remaining > .zero }
            .sorted { $0.remaining > $1.remaining }
            .first
    }

    private var remainingPercent: Double {
        guard overview.monthlyBudget > .zero else { return 0 }
        return max(0, min(1, overview.remaining.doubleValue / overview.monthlyBudget.doubleValue))
    }

    private func barTint(for row: CategorySpendRow) -> Color {
        if row.isOverBudget { return BudgetTheme.red }
        if row.isCloseToBudget { return BudgetTheme.yellow }
        return BudgetTheme.green
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var active = categories.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }
        active.move(fromOffsets: source, toOffset: destination)
        for (index, category) in active.enumerated() {
            category.sortOrder = index
            category.touch()
        }
        try? modelContext.save()
    }
}

struct BudgetModifierView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categories: [BudgetCategory]
    @State private var percentChange: Decimal = 10

    private var totalBudget: Decimal {
        categories.reduce(.zero) { $0 + $1.monthlyBudget }
    }

    var body: some View {
        List {
            Section {
                MetricTile(title: "Plan", value: MoneyFormatter.string(totalBudget), footnote: "\(categories.count) active line(s)", tint: BudgetTheme.rust)
                HStack {
                    Text("Adjust all by")
                    Spacer()
                    TextField("0", value: $percentChange, format: .number)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
                Button {
                    applyPercentChange()
                } label: {
                    Label("Apply Modifier", systemImage: "percent")
                }
                .buttonStyle(.borderedProminent)
            } header: {
                Text("Modifier")
            } footer: {
                Text("Use a negative number to reduce every active budget line.")
            }

            Section("Budget Lines") {
                ForEach(categories) { category in
                    HStack {
                        Label(category.name, systemImage: category.symbol)
                        Spacer()
                        TextField("0", value: budgetBinding(for: category), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 130)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(category.name) budget \(MoneyFormatter.string(category.monthlyBudget))")
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Budget Modifier")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private func budgetBinding(for category: BudgetCategory) -> Binding<Decimal> {
        Binding(
            get: { category.monthlyBudget },
            set: { newValue in
                category.monthlyBudget = max(.zero, newValue)
                category.touch()
                try? modelContext.save()
            }
        )
    }

    private func applyPercentChange() {
        let multiplier = max(.zero, (Decimal(100) + percentChange) / Decimal(100))
        for category in categories {
            category.monthlyBudget = (category.monthlyBudget * multiplier).roundedToPaise
            category.touch()
        }
        try? modelContext.save()
    }
}
