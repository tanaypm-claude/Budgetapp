import SwiftUI
import SwiftData
import Charts

/// Useful, not decorative: income vs expenses, where the money went, recurring
/// load, and anything unusual — all for a month you can scrub through.
struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var recurring: [RecurringPayment]

    @State private var referenceMonth = Date.now

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }

    private var flows: [ReportsCalculator.MonthFlow] {
        ReportsCalculator.monthlyFlows(months: 6, endingAt: .now, transactions: transactions)
    }

    /// Flattened income/expense points for the grouped bar chart.
    private struct FlowPoint: Identifiable {
        let id = UUID()
        let month: Date
        let kind: String
        let amount: Double
    }
    private var flowSeries: [FlowPoint] {
        flows.flatMap { flow in
            [
                FlowPoint(month: flow.month, kind: "Income", amount: NSDecimalNumber(decimal: flow.income).doubleValue),
                FlowPoint(month: flow.month, kind: "Expenses", amount: NSDecimalNumber(decimal: flow.expense).doubleValue)
            ]
        }
    }
    private var categoryTotals: [ReportsCalculator.CategoryTotal] {
        ReportsCalculator.categorySpending(month: referenceMonth, transactions: transactions)
    }
    private var monthIncome: Decimal { BudgetCalculator.totalIncome(month: referenceMonth, transactions: transactions) }
    private var monthExpense: Decimal { BudgetCalculator.totalSpent(month: referenceMonth, transactions: transactions) }
    private var recurringMonthly: Decimal {
        recurring.filter(\.isActive).reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
    }
    private var unusual: [Transaction] {
        ReportsCalculator.unusualTransactions(transactions: transactions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    monthScrubber
                    incomeExpenseCard
                    flowsCard
                    categoryBreakdownCard
                    recurringCard
                    if !unusual.isEmpty { unusualCard }
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.paper)
            .navigationTitle("Reports")
        }
    }

    // MARK: Sections

    private var monthScrubber: some View {
        HStack {
            Button { referenceMonth = referenceMonth.addingMonths(-1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(referenceMonth.monthYear).font(.ledgerHeadline()).foregroundStyle(Theme.ink)
            Spacer()
            Button { referenceMonth = referenceMonth.addingMonths(1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(Calendar.current.isDate(referenceMonth, equalTo: .now, toGranularity: .month))
        }
        .padding(.horizontal, Theme.Space.sm)
    }

    private var incomeExpenseCard: some View {
        LedgerCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionLabel("Income vs Expenses")
                HStack(spacing: Theme.Space.xl) {
                    figure("Income", monthIncome, Theme.positive)
                    figure("Expenses", monthExpense, Theme.negative)
                    figure("Net", monthIncome - monthExpense, (monthIncome - monthExpense) < 0 ? Theme.negative : Theme.ink)
                }
            }
        }
    }

    private var flowsCard: some View {
        LedgerCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionLabel("Last 6 months")
                Chart(flowSeries) { point in
                    BarMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(by: .value("Kind", point.kind))
                    .position(by: .value("Kind", point.kind))
                }
                .chartForegroundStyleScale(["Income": Theme.positive, "Expenses": Theme.negative])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private var categoryBreakdownCard: some View {
        LedgerCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionLabel("Where it went")
                if categoryTotals.isEmpty {
                    Text("No spending this month.").font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                } else {
                    ForEach(categoryTotals.prefix(8)) { total in
                        categoryBar(total)
                    }
                }
            }
        }
    }

    private func categoryBar(_ total: ReportsCalculator.CategoryTotal) -> some View {
        let category = lookups.category(total.categoryId)
        let maxAmount = categoryTotals.first?.amount ?? 1
        let fraction = doubleValue(total.amount) / max(doubleValue(maxAmount), 0.0001)
        return VStack(spacing: 4) {
            HStack {
                Text(category?.name ?? "Uncategorised")
                    .font(.ledgerCaption().weight(.medium)).foregroundStyle(Theme.ink)
                Spacer()
                Text(CurrencyFormatter.compact(total.amount))
                    .font(.ledgerNumber(.caption, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
            }
            BudgetBar(fraction: fraction, tint: Color(hex: category?.colorHex ?? "#9A9384"), height: 6)
        }
    }

    private var recurringCard: some View {
        LedgerCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel("Recurring load")
                    Text("Active subscriptions & bills, per month")
                        .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Text(CurrencyFormatter.string(recurringMonthly))
                    .font(.ledgerNumber(.title3, weight: .bold)).foregroundStyle(Theme.ink)
            }
        }
    }

    private var unusualCard: some View {
        LedgerCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionLabel("Unusual activity")
                ForEach(unusual.prefix(5)) { txn in
                    HStack(spacing: Theme.Space.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Theme.warning)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(txn.merchant.isEmpty ? txn.narration : txn.merchant)
                                .font(.ledgerCaption().weight(.medium)).foregroundStyle(Theme.ink).lineLimit(1)
                            Text("\(lookups.categoryName(txn.categoryId)) · \(txn.date.shortDay)")
                                .font(.system(size: 11, design: .rounded)).foregroundStyle(Theme.inkFaint)
                        }
                        Spacer()
                        Text(CurrencyFormatter.compact(txn.magnitude))
                            .font(.ledgerNumber(.caption, weight: .semibold)).foregroundStyle(Theme.negative)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func figure(_ label: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8).foregroundStyle(Theme.inkFaint)
            Text(CurrencyFormatter.compact(amount))
                .font(.ledgerNumber(.body, weight: .bold)).foregroundStyle(color)
        }
    }

    private func monthlyEquivalent(_ payment: RecurringPayment) -> Decimal {
        switch payment.frequency {
        case .weekly: return payment.amount * Decimal(52) / 12
        case .biweekly: return payment.amount * Decimal(26) / 12
        case .monthly: return payment.amount
        case .quarterly: return payment.amount / 3
        case .yearly: return payment.amount / 12
        }
    }

    private func doubleValue(_ decimal: Decimal) -> Double { NSDecimalNumber(decimal: decimal).doubleValue }
}

#Preview {
    ReportsView()
        .modelContainer(PreviewData.container())
}
