import SwiftUI

/// A single ledger line: category glyph, merchant + meta, and a signed amount.
struct TransactionRow: View {
    let transaction: Transaction
    let lookups: Lookups
    var showsDate: Bool = true

    private var category: Category? { lookups.category(transaction.categoryId) }

    private var amountColor: Color {
        switch transaction.type {
        case .income: return Theme.positive
        case .expense: return Theme.ink
        case .transfer: return Theme.inkSecondary
        }
    }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            CategoryGlyph(
                symbol: category?.symbol ?? "questionmark",
                colorHex: category?.colorHex ?? "#9A9384"
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant.isEmpty ? transaction.narration : transaction.merchant)
                    .font(.ledgerBody().weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(lookups.categoryName(transaction.categoryId))
                    if showsDate {
                        Text("·")
                        Text(transaction.date.shortDay)
                    }
                    if !transaction.isReviewed {
                        Text("·")
                        Label("Review", systemImage: "questionmark.circle")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(Theme.warning)
                    }
                }
                .font(.ledgerCaption())
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.sm)

            Text(CurrencyFormatter.signed(transaction.amount, type: transaction.type))
                .font(.ledgerNumber(.callout, weight: .semibold))
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let name = transaction.merchant.isEmpty ? transaction.narration : transaction.merchant
        let amount = CurrencyFormatter.signed(transaction.amount, type: transaction.type)
        let review = transaction.isReviewed ? "" : ", needs review"
        return "\(name), \(lookups.categoryName(transaction.categoryId)), \(amount), \(transaction.date.friendlyDay)\(review)"
    }
}
