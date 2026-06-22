import SwiftUI

/// The hero readout: a confident "safe to spend per day" figure framed like an
/// instrument, with the month's budget/spent/remaining beneath it.
struct SafeToSpendPanel: View {
    let overview: MonthlyOverview

    private var isOver: Bool { overview.remainingBudget < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            HStack {
                Label("Safe to spend / day", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.ledgerCaption().weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Text("\(overview.daysLeftInMonth) days left")
                    .font(.ledgerCaption())
                    .foregroundStyle(Theme.inkFaint)
            }

            Text(CurrencyFormatter.string(overview.safeToSpendPerDay))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isOver ? Theme.negative : Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())

            BudgetBar(fraction: overview.fractionSpent, tint: Theme.accent, height: 10)

            HStack {
                metric("Budget", CurrencyFormatter.compact(overview.totalBudget), Theme.inkSecondary)
                Spacer()
                metric("Spent", CurrencyFormatter.compact(overview.totalSpent), Theme.ink)
                Spacer()
                metric(
                    isOver ? "Over" : "Remaining",
                    CurrencyFormatter.compact(abs(overview.remainingBudget)),
                    isOver ? Theme.negative : Theme.positive
                )
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.surface, Theme.surfaceSunken],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Theme.inkFaint)
            Text(value)
                .font(.ledgerNumber(.subheadline, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func abs(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}
