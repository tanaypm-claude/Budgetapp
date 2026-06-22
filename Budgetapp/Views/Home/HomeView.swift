import SwiftUI
import SwiftData

/// The personal "instrument panel": what's safe to spend, what needs attention,
/// and a glance at recent activity. Deliberately not a grid of generic KPI cards.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var recurring: [RecurringPayment]

    private let referenceMonth = Date.now

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }

    private var activeCategories: [Category] { categories.filter { $0.isActive && $0.monthlyBudget > 0 } }

    private var totalBudget: Decimal {
        activeCategories.reduce(Decimal(0)) { $0 + $1.monthlyBudget }
    }

    private var overview: MonthlyOverview {
        BudgetCalculator.monthlyOverview(totalBudget: totalBudget, month: referenceMonth, transactions: transactions)
    }

    private var categorySummaries: [CategorySpendSummary] {
        BudgetCalculator.categorySummaries(
            categories: activeCategories.map { ($0.id, $0.monthlyBudget) },
            month: referenceMonth,
            transactions: transactions
        )
    }

    private var attentionCategories: [(Category, CategorySpendSummary)] {
        let summaryById = Dictionary(uniqueKeysWithValues: categorySummaries.map { ($0.categoryId, $0) })
        return activeCategories.compactMap { category in
            guard let summary = summaryById[category.id], summary.isNearLimit || summary.isOverBudget else { return nil }
            return (category, summary)
        }
        .sorted { $0.1.fractionUsed > $1.1.fractionUsed }
    }

    private var needsReview: [Transaction] { transactions.filter { !$0.isReviewed } }

    private var upcomingRecurring: [RecurringPayment] {
        recurring.filter(\.isActive)
            .sorted { $0.nextExpectedDate < $1.nextExpectedDate }
            .prefix(3)
            .map { $0 }
    }

    private var recentTransactions: [Transaction] { Array(transactions.prefix(6)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    SafeToSpendPanel(overview: overview)

                    if !needsReview.isEmpty {
                        reviewBanner
                    }

                    if !attentionCategories.isEmpty {
                        attentionSection
                    }

                    if !upcomingRecurring.isEmpty {
                        upcomingSection
                    }

                    recentSection
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.paper)
            .navigationTitle(referenceMonth.monthYear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        TransactionEditorView(mode: .create)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
        }
    }

    // MARK: Sections

    private var reviewBanner: some View {
        NavigationLink {
            ReviewQueueView()
        } label: {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: "tray.full")
                    .font(.title3)
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(needsReview.count) to review")
                        .font(.ledgerBody().weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Imported items waiting for a category")
                        .font(.ledgerCaption())
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkFaint)
            }
            .padding(Theme.Space.lg)
            .background(Theme.warning.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var attentionSection: some View {
        let items = attentionCategories
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionLabel("Watch list")
            LedgerCard {
                VStack(spacing: Theme.Space.md) {
                    ForEach(items.indices, id: \.self) { index in
                        CategoryProgressRow(category: items[index].0, summary: items[index].1)
                        if index < items.count - 1 { Divider().overlay(Theme.hairline) }
                    }
                }
            }
        }
    }

    private var upcomingSection: some View {
        let items = upcomingRecurring
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionLabel("Upcoming") {
                NavigationLink("All") { RecurringListView() }
                    .font(.ledgerCaption())
            }
            LedgerCard {
                VStack(spacing: Theme.Space.md) {
                    ForEach(items) { payment in
                        UpcomingRecurringRow(payment: payment, lookups: lookups)
                        if payment.id != items.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionLabel("Recent") {
                NavigationLink("All") { TransactionsView() }
                    .font(.ledgerCaption())
            }
            if recentTransactions.isEmpty {
                LedgerCard {
                    EmptyStateView(
                        icon: "tray",
                        title: "No transactions yet",
                        message: "Add one manually or import a statement to get started."
                    )
                }
            } else {
                let items = recentTransactions
                LedgerCard {
                    VStack(spacing: Theme.Space.sm) {
                        ForEach(items) { txn in
                            NavigationLink {
                                TransactionEditorView(mode: .edit(txn))
                            } label: {
                                TransactionRow(transaction: txn, lookups: lookups)
                            }
                            .buttonStyle(.plain)
                            if txn.id != items.last?.id { Divider().overlay(Theme.hairline) }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container())
}
