import SwiftData
import SwiftUI

struct MonthReport: Identifiable {
    var id: String { label }
    let label: String
    let income: Decimal
    let expenses: Decimal
}

struct ReportsView: View {
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \RecurringPayment.nextExpectedDate) private var recurringPayments: [RecurringPayment]

    private var overview: BudgetOverview {
        BudgetMath.overview(transactions: transactions, categories: categories)
    }

    private var categoryRows: [CategorySpendRow] {
        BudgetMath.categoryRows(transactions: transactions, categories: categories)
            .filter { $0.spent > 0 || $0.budget > 0 }
            .sorted { $0.spent > $1.spent }
    }

    private var monthReports: [MonthReport] {
        (-5...0).map { offset in
            let date = Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()
            let net = BudgetMath.monthlyNet(transactions: transactions, monthOffset: offset)
            return MonthReport(label: AppDateFormatters.month.string(from: date), income: net.income, expenses: net.expenses)
        }
    }

    private var recurringTotal: Decimal {
        recurringPayments.filter(\.isActive).reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var unusualTransactions: [BudgetTransaction] {
        let expenses = transactions.filter { $0.type == .expense }
        guard !expenses.isEmpty else { return [] }
        let average = expenses.reduce(Decimal.zero) { $0 + $1.amount } / Decimal(expenses.count)
        return expenses
            .filter { $0.amount > max(average * 2, Decimal(5000)) }
            .sorted { $0.amount > $1.amount }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                reportOverviewPanel
                unusualTransactionsPanel
                categoryMixPanel
                monthRhythmPanel
                categoryPressurePanel
            }
            .padding()
        }
        .budgetScreenBackground()
        .navigationTitle("Reports")
    }

    private var maxMonthlyValue: Decimal {
        max(Decimal(1), monthReports.flatMap { [$0.income, $0.expenses] }.max() ?? 1)
    }

    private var maxCategoryTrendValue: Decimal {
        let values = categories.flatMap { category in
            (-5...0).map { monthlySpend(category: category, offset: $0) }
        }
        return max(Decimal(1), values.max() ?? 1)
    }

    private var savedThisMonth: Decimal {
        overview.income - overview.spent
    }

    private var savingRate: Double {
        guard overview.income > .zero else { return overview.spent > .zero ? 0 : 1 }
        return max(0, min(1, savedThisMonth.doubleValue / overview.income.doubleValue))
    }

    private var spendingRate: Double {
        guard overview.income > .zero else { return overview.spent > .zero ? 1 : 0 }
        return max(0, min(1, overview.spent.doubleValue / overview.income.doubleValue))
    }

    private var categorySlices: [DonutSlice] {
        let palette = [BudgetTheme.blue, BudgetTheme.green, BudgetTheme.yellow, BudgetTheme.red, BudgetTheme.lightBlue]
        return Array(categoryRows.prefix(6).enumerated()).map { index, row in
            DonutSlice(value: row.spent, color: palette[index % palette.count])
        }
    }

    private var reportOverviewPanel: some View {
        LedgerPanel(title: nil, subtitle: nil) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StatInstrument(
                        title: "Spent",
                        value: MoneyFormatter.string(overview.spent),
                        footnote: "\(Int(overview.percentUsed * 100))% of plan",
                        symbol: "💵",
                        percent: overview.percentUsed,
                        tint: BudgetTheme.stressTint(overview.percentUsed),
                        usesStressGradient: true
                    )
                    StatInstrument(
                        title: "Saved",
                        value: MoneyFormatter.string(savedThisMonth),
                        footnote: "Income minus spending",
                        symbol: "✨",
                        percent: savingRate,
                        tint: savedThisMonth >= .zero ? BudgetTheme.green : BudgetTheme.red
                    )
                    StatInstrument(
                        title: "Recurring",
                        value: MoneyFormatter.string(recurringTotal),
                        footnote: "Active expected total",
                        symbol: "🔁",
                        percent: overview.monthlyBudget > .zero ? min(1, recurringTotal.doubleValue / overview.monthlyBudget.doubleValue) : 0,
                        tint: BudgetTheme.blue
                    )
                }
            }
        }
    }

    private var unusualTransactionsPanel: some View {
        LedgerPanel(title: "Unusual Transactions", subtitle: "Large expenses compared with your own ledger") {
            if unusualTransactions.isEmpty {
                ContentUnavailableView("Nothing Unusual", systemImage: "checkmark.seal")
                    .frame(minHeight: 100)
            } else {
                VStack(spacing: 12) {
                    ForEach(unusualTransactions) { transaction in
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(BudgetTheme.yellow)
                                .frame(width: 34, height: 34)
                                .background(BudgetTheme.yellow.opacity(0.16), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.merchant)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BudgetTheme.ink)
                                Text(AppDateFormatters.short.string(from: transaction.date))
                                    .font(.caption)
                                    .foregroundStyle(BudgetTheme.secondaryInk)
                            }
                            Spacer()
                            Text(MoneyFormatter.string(transaction.amount))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(BudgetTheme.ink)
                                .privacySensitive()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var categoryMixPanel: some View {
        LedgerPanel(title: "Category Mix", subtitle: AppDateFormatters.month.string(from: Date())) {
            if categoryRows.isEmpty {
                ContentUnavailableView("No Spending Yet", systemImage: "chart.pie")
                    .frame(minHeight: 120)
            } else {
                HStack(alignment: .center, spacing: 18) {
                    DonutChart(slices: categorySlices, lineWidth: 24)
                        .frame(width: 118, height: 118)
                    VStack(spacing: 10) {
                        ForEach(Array(categoryRows.prefix(5).enumerated()), id: \.element.id) { index, row in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill([BudgetTheme.blue, BudgetTheme.green, BudgetTheme.yellow, BudgetTheme.red, BudgetTheme.lightBlue][index % 5])
                                    .frame(width: 9, height: 9)
                                Text(row.category.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BudgetTheme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(MoneyFormatter.string(row.spent, compact: true))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BudgetTheme.secondaryInk)
                                    .privacySensitive()
                            }
                        }
                    }
                }
            }
        }
    }

    private var monthRhythmPanel: some View {
        LedgerPanel(title: "Spend Save Rhythm", subtitle: "Last six months") {
            VStack(alignment: .leading, spacing: 14) {
                ReportLinePulse(
                    income: monthReports.map(\.income),
                    expenses: monthReports.map(\.expenses),
                    maxValue: maxMonthlyValue
                )
                .frame(height: 134)

                HStack {
                    Text(monthReports.first.map { String($0.label.prefix(3)) } ?? "")
                    Spacer()
                    Label("income", systemImage: "circle.fill")
                        .foregroundStyle(BudgetTheme.green)
                    Label("spend", systemImage: "circle.fill")
                        .foregroundStyle(BudgetTheme.red)
                    Spacer()
                    Text(monthReports.last.map { String($0.label.prefix(3)) } ?? "")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(BudgetTheme.secondaryInk)

                InstrumentBar(percent: spendingRate, inverse: false)
                InstrumentBar(percent: savingRate, tint: savedThisMonth >= .zero ? BudgetTheme.green : BudgetTheme.red)
            }
        }
    }

    private var categoryPressurePanel: some View {
        LedgerPanel(title: "Budget Pressure", subtitle: "Horizontal rails show proximity to plan") {
            if categoryRows.isEmpty {
                ContentUnavailableView("No Active Budgets", systemImage: "dial.low")
                    .frame(minHeight: 120)
            } else {
                VStack(spacing: 14) {
                    ForEach(categoryRows) { row in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Image(systemName: row.category.symbol)
                                    .foregroundStyle(row.isOverBudget ? BudgetTheme.red : row.isCloseToBudget ? BudgetTheme.yellow : BudgetTheme.green)
                                    .frame(width: 28, height: 28)
                                    .background((row.isOverBudget ? BudgetTheme.red : row.isCloseToBudget ? BudgetTheme.yellow : BudgetTheme.green).opacity(0.16), in: Circle())
                                Text(row.category.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BudgetTheme.ink)
                                Spacer()
                                Text("\(Int(row.percentUsed * 100))%")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(BudgetTheme.secondaryInk)
                            }
                            InstrumentBar(percent: min(1.25, row.percentUsed), tint: nil)
                            HStack {
                                Text(MoneyFormatter.string(row.spent))
                                    .privacySensitive()
                                Spacer()
                                Text(row.remaining >= .zero ? "\(MoneyFormatter.string(row.remaining)) left" : "\(MoneyFormatter.string(row.remaining.absoluteValue)) over")
                                    .privacySensitive()
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BudgetTheme.secondaryInk)
                            .privacySensitive()
                        }
                    }
                }
            }
        }
    }

    private func monthlySpend(category: BudgetCategory, offset: Int) -> Decimal {
        let date = Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        let interval = BudgetMath.monthInterval(containing: date)
        return transactions
            .filter { $0.type == .expense && $0.categoryId == category.id && BudgetMath.isDate($0.date, inside: interval) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
}

private struct ReportLinePulse: View {
    var income: [Decimal]
    var expenses: [Decimal]
    var maxValue: Decimal

    var body: some View {
        Canvas { context, size in
            draw(values: income, color: BudgetTheme.green, context: &context, size: size)
            draw(values: expenses, color: BudgetTheme.red, context: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(values: [Decimal], color: Color, context: inout GraphicsContext, size: CGSize) {
        guard !values.isEmpty else { return }
        var path = Path()
        for index in values.indices {
            let x = size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
            let normalized = values[index].doubleValue / maxValue.doubleValue
            let y = size.height - size.height * CGFloat(max(0, min(1, normalized)))
            if index == values.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        for index in values.indices {
            let x = size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
            let normalized = values[index].doubleValue / maxValue.doubleValue
            let y = size.height - size.height * CGFloat(max(0, min(1, normalized)))
            var dot = Path()
            dot.addEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
            context.fill(dot, with: .color(color))
        }
    }
}
