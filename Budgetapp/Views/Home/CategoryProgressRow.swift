import SwiftUI

/// One category's spend vs budget: glyph, name, figures, and a progress rule.
struct CategoryProgressRow: View {
    let category: Category
    let summary: CategorySpendSummary

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.md) {
                CategoryGlyph(symbol: category.symbol, colorHex: category.colorHex, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.ledgerBody().weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Text(statusText)
                        .font(.ledgerCaption())
                        .foregroundStyle(summary.isOverBudget ? Theme.negative : Theme.inkSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(CurrencyFormatter.compact(summary.spent))
                        .font(.ledgerNumber(.callout, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("of \(CurrencyFormatter.compact(summary.budget))")
                        .font(.ledgerCaption())
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            BudgetBar(fraction: summary.fractionUsed, tint: Color(hex: category.colorHex))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), \(statusText)")
    }

    private var statusText: String {
        if summary.isOverBudget {
            return "Over by \(CurrencyFormatter.compact(summary.spent - summary.budget))"
        }
        let percent = Int((summary.fractionUsed * 100).rounded())
        return "\(percent)% used · \(CurrencyFormatter.compact(summary.remaining)) left"
    }
}
