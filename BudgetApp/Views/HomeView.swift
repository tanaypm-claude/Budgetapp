import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \RecurringPayment.nextExpectedDate) private var recurringPayments: [RecurringPayment]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]
    @Query(sort: \Project.name) private var projects: [Project]

    private var overview: BudgetOverview {
        BudgetMath.overview(transactions: transactions, categories: categories)
    }

    private var categoryRows: [CategorySpendRow] {
        BudgetMath.categoryRows(transactions: transactions, categories: categories)
    }

    private var reviewTransactions: [BudgetTransaction] {
        transactions.filter { !$0.isReviewed }
    }

    private var upcomingRecurring: [RecurringPayment] {
        let horizon = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()
        return recurringPayments
            .filter { $0.isActive && $0.nextExpectedDate <= horizon }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                safeSpendPanel
                reportSnapshotPanel
                attentionPanel
                recurringPanel
                recentPanel
            }
            .padding()
        }
        .budgetScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var safeSpendPanel: some View {
        LedgerPanel(title: "Safe to Spend", subtitle: "\(overview.daysLeft) day(s) left this month") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(MoneyFormatter.string(overview.safeToSpendDaily))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(BudgetTheme.ink)
                        .privacySensitive()
                    Text("/ day")
                        .font(.headline)
                        .foregroundStyle(BudgetTheme.secondaryInk)
                }
                budgetStatusStrip
                quickStatsGrid
            }
        }
    }

    private var budgetStatusStrip: some View {
        HStack(spacing: 12) {
            StatusGlyph(tone: remainingTone)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Spent \(MoneyFormatter.string(overview.spent)) of \(MoneyFormatter.string(overview.monthlyBudget))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BudgetTheme.ink)
                    .privacySensitive()
                Text(overview.remaining < .zero ? "\(MoneyFormatter.string(overview.remaining.absoluteValue)) over budget" : "\(MoneyFormatter.string(overview.remaining)) still unspent")
                    .font(.caption)
                    .foregroundStyle(BudgetTheme.secondaryInk)
                    .privacySensitive()
            }
            Spacer()
            Text("\(Int(overview.percentUsed * 100))%")
                .font(.headline.monospacedDigit())
                .foregroundStyle(BudgetTheme.secondaryInk)
                .privacySensitive()
        }
        .padding(10)
        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            QuickStatBlock(
                title: "Spent",
                value: MoneyFormatter.string(overview.spent),
                footnote: "\(Int(overview.percentUsed * 100))% used",
                symbol: "💵",
                percent: overview.percentUsed,
                tint: BudgetTheme.signalTint(overview.percentUsed)
            )
            QuickStatBlock(
                title: "Remaining",
                value: MoneyFormatter.string(overview.remaining),
                footnote: overview.remaining < .zero ? "Over plan" : "Available",
                symbol: "👛",
                percent: remainingPercent,
                tint: BudgetTheme.signalTint(remainingPercent, inverse: true),
                inverse: true
            )
            QuickStatBlock(
                title: "Income",
                value: MoneyFormatter.string(overview.income),
                footnote: "This month",
                symbol: "🎉",
                percent: incomePercent,
                tint: incomeTint,
                inverse: overview.income > .zero
            )
            QuickStatBlock(
                title: "Attention",
                value: "\(attentionCount)",
                footnote: attentionCount == 0 ? "All clear" : "Review now",
                symbol: "⚠️",
                percent: attentionPercent,
                tint: attentionTint
            )
        }
    }

    private var reportSnapshotPanel: some View {
        LedgerPanel(title: nil, subtitle: nil) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategorySplitCard(rows: categoryRows.filter { $0.spent > .zero })
                    SavingPulseCard(income: overview.income, spent: overview.spent)
                    MonthLineCard(reports: monthReports, maxValue: maxMonthlyValue)
                    NavigationLink {
                        ReportsView()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("↗")
                                .font(.largeTitle.weight(.black))
                            Text("Expanded reports")
                                .font(.headline)
                            Text("Outliers, category concentration, recurring pressure")
                                .font(.caption)
                                .foregroundStyle(BudgetTheme.secondaryInk)
                        }
                        .foregroundStyle(BudgetTheme.ink)
                        .padding(16)
                        .frame(width: 230, height: 170, alignment: .leading)
                        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var attentionPanel: some View {
        LedgerPanel(title: "Needs Attention", subtitle: "Only the rows that can change a decision") {
            VStack(spacing: 12) {
                let warningRows = categoryRows.filter { $0.isOverBudget || $0.isCloseToBudget }
                if warningRows.isEmpty && reviewTransactions.isEmpty {
                    ContentUnavailableView("All Clear", systemImage: "checkmark.seal", description: Text("No category is close to budget and no imports are waiting."))
                        .frame(minHeight: 120)
                } else {
                    ForEach(warningRows.prefix(4)) { row in
                        HStack(spacing: 12) {
                            Image(systemName: row.category.symbol)
                                .foregroundStyle(row.isOverBudget ? BudgetTheme.red : BudgetTheme.yellow)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.category.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.isOverBudget ? "\(MoneyFormatter.string(row.remaining.absoluteValue)) over budget" : "\(Int(row.percentUsed * 100))% used")
                                    .font(.caption)
                                    .foregroundStyle(BudgetTheme.secondaryInk)
                                    .privacySensitive(row.isOverBudget)
                            }
                            Spacer()
                            Text(MoneyFormatter.string(row.spent))
                                .font(.subheadline.monospacedDigit())
                                .privacySensitive()
                        }
                        .accessibilityElement(children: .combine)
                    }

                    if !reviewTransactions.isEmpty {
                        NavigationLink {
                            ImportHubView()
                        } label: {
                            Label("\(reviewTransactions.count) transaction(s) need review", systemImage: "tray.and.arrow.down.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var recurringPanel: some View {
        LedgerPanel(title: "Upcoming", subtitle: "Recurring payments in the next 45 days") {
            if upcomingRecurring.isEmpty {
                ContentUnavailableView("No Upcoming Payments", systemImage: "calendar.badge.checkmark")
                    .frame(minHeight: 100)
            } else {
                VStack(spacing: 10) {
                    ForEach(upcomingRecurring) { payment in
                        HStack(spacing: 12) {
                            CategoryPill(category: categories.category(id: payment.categoryId))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(AppDateFormatters.short.string(from: payment.nextExpectedDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(MoneyFormatter.string(payment.amount))
                                .font(.subheadline.monospacedDigit())
                                .privacySensitive()
                        }
                    }
                }
            }
        }
    }

    private var recentPanel: some View {
        LedgerPanel(title: "Recent Ledger", subtitle: "Latest manual and imported entries") {
            if transactions.isEmpty {
                ContentUnavailableView("No Transactions Yet", systemImage: "square.and.pencil", description: Text("Add one manually or import a statement."))
                    .frame(minHeight: 120)
            } else {
                VStack(spacing: 12) {
                    ForEach(transactions.prefix(6)) { transaction in
                        HStack(spacing: 12) {
                            Image(systemName: transaction.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundStyle(transaction.type == .income ? BudgetTheme.green : BudgetTheme.red)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(transaction.merchant)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                HStack {
                                    CategoryPill(category: categories.category(id: transaction.categoryId))
                                    Text(accounts.account(id: transaction.accountId)?.name ?? "No account")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(MoneyFormatter.string(transaction.amount))
                                    .font(.subheadline.monospacedDigit())
                                    .privacySensitive()
                                Text(AppDateFormatters.dayMonth.string(from: transaction.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    NavigationLink {
                        TransactionsView()
                    } label: {
                        Label("Open full ledger", systemImage: "arrow.up.right.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var monthReports: [MonthReport] {
        (-5...0).map { offset in
            let date = Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()
            let net = BudgetMath.monthlyNet(transactions: transactions, monthOffset: offset)
            return MonthReport(label: AppDateFormatters.month.string(from: date), income: net.income, expenses: net.expenses)
        }
    }

    private var maxMonthlyValue: Decimal {
        max(Decimal(1), monthReports.flatMap { [$0.income, $0.expenses] }.max() ?? 1)
    }

    private var remainingPercent: Double {
        guard overview.monthlyBudget > .zero else { return 0 }
        return max(0, min(1, overview.remaining.doubleValue / overview.monthlyBudget.doubleValue))
    }

    private var incomePercent: Double {
        guard overview.monthlyBudget > .zero else { return overview.income > .zero ? 1 : 0 }
        return max(0, min(1, overview.income.doubleValue / overview.monthlyBudget.doubleValue))
    }

    private var attentionCount: Int {
        categoryRows.filter { $0.isOverBudget || $0.isCloseToBudget }.count + reviewTransactions.count
    }

    private var attentionPercent: Double {
        min(1, Double(attentionCount) / 4)
    }

    private var attentionTint: Color {
        if attentionCount == 0 { return BudgetTheme.green }
        if attentionCount < 3 { return BudgetTheme.yellow }
        return BudgetTheme.red
    }

    private var incomeTint: Color {
        return BudgetTheme.signalTint(incomePercent, inverse: true)
    }

    private var remainingTone: StatusGlyph.Tone {
        if overview.remaining < .zero { return .negative }
        if overview.percentUsed >= 0.8 { return .attention }
        return .positive
    }

}

private struct QuickStatBlock: View {
    var title: String
    var value: String
    var footnote: String
    var symbol: String
    var percent: Double
    var tint: Color
    var inverse = false

    private var clampedPercent: Double {
        max(0, min(1, percent))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BudgetTheme.tile)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.24))
                    .frame(width: fillWidth(total: proxy.size.width))
                    .shadow(color: tint.opacity(0.30), radius: 14, x: 0, y: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(symbol)
                        .font(.title3)
                        .frame(width: 31, height: 31)
                        .background(tint.opacity(0.24), in: Circle())
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BudgetTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(BudgetTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .privacySensitive()
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(BudgetTheme.secondaryInk)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: tint.opacity(0.12), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func fillWidth(total: CGFloat) -> CGFloat {
        guard clampedPercent > 0 else { return 0 }
        return max(18, total * CGFloat(clampedPercent))
    }
}

private struct CategorySplitCard: View {
    var rows: [CategorySpendRow]

    private var slices: [DonutSlice] {
        Array(rows.prefix(5).enumerated()).map { index, row in
            DonutSlice(value: row.spent, color: palette[index % palette.count])
        }
    }

    private let palette: [Color] = [BudgetTheme.blue, BudgetTheme.green, BudgetTheme.yellow, BudgetTheme.red, BudgetTheme.lightBlue]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DonutChart(slices: slices, lineWidth: 18)
                    .frame(width: 78, height: 78)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category split")
                        .font(.headline)
                    Text(rows.first?.category.name ?? "No spending yet")
                        .font(.caption)
                        .foregroundStyle(BudgetTheme.secondaryInk)
                }
            }
            ForEach(Array(rows.prefix(3).enumerated()), id: \.element.id) { index, row in
                HStack {
                    Circle().fill(palette[index % palette.count]).frame(width: 8, height: 8)
                    Text(row.category.name).lineLimit(1)
                    Spacer()
                    Text(MoneyFormatter.string(row.spent, compact: true)).privacySensitive()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .frame(width: 260, height: 170, alignment: .leading)
        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SavingPulseCard: View {
    var income: Decimal
    var spent: Decimal

    private var saving: Decimal { income - spent }
    private var savingRate: Double {
        guard income > .zero else { return spent > .zero ? 0 : 1 }
        return max(0, min(1, saving.doubleValue / income.doubleValue))
    }
    private var spendingRate: Double {
        guard income > .zero else { return spent > .zero ? 1 : 0 }
        return max(0, min(1, spent.doubleValue / income.doubleValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spend vs save")
                .font(.headline)
            InstrumentBar(percent: spendingRate, inverse: false)
            InstrumentBar(percent: savingRate, tint: saving >= .zero ? BudgetTheme.green : BudgetTheme.red)
            HStack {
                Text(saving >= .zero ? "Saved" : "Short")
                Spacer()
                Text(MoneyFormatter.string(saving)).privacySensitive()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(16)
        .frame(width: 242, height: 170, alignment: .leading)
        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MonthLineCard: View {
    var reports: [MonthReport]
    var maxValue: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Six month rhythm")
                .font(.headline)
            Sparkline(values: reports.map(\.expenses), maxValue: maxValue, tint: BudgetTheme.red)
                .frame(height: 74)
            HStack {
                Text(reports.first.map { String($0.label.prefix(3)) } ?? "")
                Spacer()
                Text(reports.last.map { String($0.label.prefix(3)) } ?? "")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(BudgetTheme.secondaryInk)
        }
        .padding(16)
        .frame(width: 242, height: 170, alignment: .leading)
        .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct Sparkline: View {
    var values: [Decimal]
    var maxValue: Decimal
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard !values.isEmpty else { return }
                for index in values.indices {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                    let normalized = values[index].doubleValue / maxValue.doubleValue
                    let y = proxy.size.height - proxy.size.height * CGFloat(max(0, min(1, normalized)))
                    if index == values.startIndex {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
