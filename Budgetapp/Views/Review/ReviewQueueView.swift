import SwiftUI
import SwiftData

/// Imported transactions awaiting a category. Assigning one marks it reviewed
/// and drops it from the queue; the user can also spin a reusable rule from the
/// choice they just made.
struct ReviewQueueView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var ruleSeed: RuleSeed? = nil

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }
    private var queue: [Transaction] { transactions.filter { !$0.isReviewed } }

    var body: some View {
        Group {
            if queue.isEmpty {
                EmptyStateView(icon: "checkmark.seal", title: "All caught up",
                               message: "Nothing needs review. Imported items that can't be auto-categorised will show up here.")
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle("Needs Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $ruleSeed) { seed in
            NavigationStack {
                RuleEditorView(mode: .createFrom(merchant: seed.merchant, description: seed.description,
                                                 categoryId: seed.categoryId, accountId: nil))
            }
        }
    }

    private var list: some View {
        List {
            Section {
                Text("\(queue.count) item\(queue.count == 1 ? "" : "s") to confirm")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(queue) { txn in
                ReviewCard(
                    transaction: txn,
                    categories: categories.filter(\.isActive),
                    lookups: lookups,
                    onAssign: { category in assign(txn, to: category) },
                    onCreateRule: { category in seedRule(from: txn, category: category) },
                    onSkip: { markReviewedKeepingCategory(txn) }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    // MARK: Actions

    private func assign(_ txn: Transaction, to category: Category) {
        withAnimation {
            txn.categoryId = category.id
            txn.isReviewed = true
            txn.touch()
        }
        try? context.save()
        Haptics.success()
    }

    private func markReviewedKeepingCategory(_ txn: Transaction) {
        withAnimation {
            txn.isReviewed = true
            txn.touch()
        }
        try? context.save()
        Haptics.selection()
    }

    private func seedRule(from txn: Transaction, category: Category) {
        // Assign first so the queue reflects the decision, then offer the rule.
        assign(txn, to: category)
        ruleSeed = RuleSeed(merchant: txn.merchant, description: txn.narration, categoryId: category.id)
    }
}

struct RuleSeed: Identifiable {
    let id = UUID()
    let merchant: String
    let description: String
    let categoryId: UUID?
}

#Preview {
    NavigationStack { ReviewQueueView() }
        .modelContainer(PreviewData.container())
}
