import SwiftUI

/// A compact upcoming-recurring line for the Home screen.
struct UpcomingRecurringRow: View {
    let payment: RecurringPayment
    let lookups: Lookups

    private var daysAway: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                        to: Calendar.current.startOfDay(for: payment.nextExpectedDate)).day ?? 0
    }

    private var whenText: String {
        switch daysAway {
        case ..<0: return "Overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "in \(daysAway) days"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            let category = lookups.category(payment.categoryId)
            CategoryGlyph(symbol: category?.symbol ?? "calendar", colorHex: category?.colorHex ?? "#5E7CE2", size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(payment.name)
                    .font(.ledgerBody().weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text("\(payment.nextExpectedDate.shortDay) · \(whenText)")
                    .font(.ledgerCaption())
                    .foregroundStyle(daysAway < 0 ? Theme.negative : Theme.inkSecondary)
            }
            Spacer()
            Text(CurrencyFormatter.compact(payment.amount))
                .font(.ledgerNumber(.callout, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(payment.name), \(CurrencyFormatter.string(payment.amount)), \(whenText)")
    }
}
