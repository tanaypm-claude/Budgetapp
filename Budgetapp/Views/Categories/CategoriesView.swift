import SwiftUI
import SwiftData

/// Manage categories: budgets, spend-so-far, reorder, archive. Spend reflects
/// the current month.
struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var transactions: [Transaction]

    @State private var showingEditor = false
    @State private var showArchived = false

    private var activeCategories: [Category] { categories.filter { showArchived || $0.isActive } }

    private func summary(for category: Category) -> CategorySpendSummary {
        CategorySpendSummary(
            categoryId: category.id,
            spent: BudgetCalculator.spent(categoryId: category.id, month: .now, transactions: transactions),
            budget: category.monthlyBudget
        )
    }

    var body: some View {
        Group {
            if activeCategories.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No categories",
                    message: "Create categories to organise spending and set budgets.",
                    actionTitle: "Add Category",
                    action: { showingEditor = true }
                )
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show archived", isOn: $showArchived)
                } label: { Image(systemName: "ellipsis.circle") }
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add category")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack { CategoryEditorView(mode: .create, nextSortOrder: categories.count) }
        }
    }

    private var list: some View {
        List {
            ForEach(activeCategories) { category in
                NavigationLink {
                    CategoryEditorView(mode: .edit(category), nextSortOrder: categories.count)
                } label: {
                    CategoryListRow(category: category, summary: summary(for: category))
                }
                .listRowBackground(Theme.surface)
                .swipeActions(edge: .trailing) {
                    if category.isActive {
                        Button { archive(category) } label: { Label("Archive", systemImage: "archivebox") }
                            .tint(Theme.inkSecondary)
                    } else {
                        Button { unarchive(category) } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
                            .tint(Theme.positive)
                    }
                }
            }
            .onMove(perform: move)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    // MARK: Actions

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = activeCategories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
            category.touch()
        }
        try? context.save()
        Haptics.selection()
    }

    private func archive(_ category: Category) {
        category.isActive = false; category.touch(); try? context.save(); Haptics.tap()
    }

    private func unarchive(_ category: Category) {
        category.isActive = true; category.touch(); try? context.save(); Haptics.tap()
    }
}

/// Compact category list row showing the budget bar + figures.
struct CategoryListRow: View {
    let category: Category
    let summary: CategorySpendSummary

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.md) {
                CategoryGlyph(symbol: category.symbol, colorHex: category.colorHex, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.ledgerBody().weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Text(category.isActive ? subtitle : "Archived")
                        .font(.ledgerCaption())
                        .foregroundStyle(summary.isOverBudget ? Theme.negative : Theme.inkSecondary)
                }
                Spacer()
                if category.monthlyBudget > 0 {
                    Text(CurrencyFormatter.compact(summary.spent))
                        .font(.ledgerNumber(.callout, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            if category.monthlyBudget > 0 {
                BudgetBar(fraction: summary.fractionUsed, tint: Color(hex: category.colorHex))
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        guard category.monthlyBudget > 0 else { return "No budget set" }
        if summary.isOverBudget {
            return "Over by \(CurrencyFormatter.compact(summary.spent - summary.budget))"
        }
        let percent = Int((summary.fractionUsed * 100).rounded())
        return "\(percent)% · \(CurrencyFormatter.compact(summary.remaining)) of \(CurrencyFormatter.compact(summary.budget)) left"
    }
}

#Preview {
    NavigationStack { CategoriesView() }
        .modelContainer(PreviewData.container())
}
