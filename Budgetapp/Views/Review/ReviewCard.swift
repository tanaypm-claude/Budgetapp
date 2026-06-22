import SwiftUI

/// A single review item: shows the imported transaction and a row of category
/// chips for one-tap assignment, plus a "make a rule" shortcut.
struct ReviewCard: View {
    let transaction: Transaction
    let categories: [Category]
    let lookups: Lookups
    let onAssign: (Category) -> Void
    let onCreateRule: (Category) -> Void
    let onSkip: () -> Void

    @State private var lastPicked: Category? = nil

    var body: some View {
        LedgerCard(padding: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.merchant.isEmpty ? transaction.narration : transaction.merchant)
                            .font(.ledgerHeadline()).foregroundStyle(Theme.ink).lineLimit(1)
                        Text("\(transaction.date.mediumDay) · \(lookups.accountName(transaction.accountId))")
                            .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Text(CurrencyFormatter.signed(transaction.amount, type: transaction.type))
                        .font(.ledgerNumber(.title3, weight: .semibold))
                        .foregroundStyle(transaction.type == .income ? Theme.positive : Theme.ink)
                }

                if !transaction.narration.isEmpty && transaction.narration != transaction.merchant {
                    Text(transaction.narration)
                        .font(.ledgerCaption()).foregroundStyle(Theme.inkFaint).lineLimit(2)
                }

                Divider().overlay(Theme.hairline)

                Text("Assign a category")
                    .font(.ledgerCaption().weight(.semibold)).foregroundStyle(Theme.inkSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.sm) {
                        ForEach(categories) { category in
                            CategoryChip(category: category, isSelected: lastPicked?.id == category.id) {
                                lastPicked = category
                                onAssign(category)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    Menu {
                        ForEach(categories) { category in
                            Button {
                                onCreateRule(category)
                            } label: { Label(category.name, systemImage: category.symbol) }
                        }
                    } label: {
                        Label("Assign & make rule", systemImage: "wand.and.stars")
                            .font(.ledgerCaption().weight(.medium))
                    }
                    Spacer()
                    Button(action: onSkip) {
                        Label("Keep as is", systemImage: "checkmark")
                            .font(.ledgerCaption())
                    }
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }
}

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.symbol).font(.system(size: 12, weight: .semibold))
                Text(category.name).font(.ledgerCaption().weight(.medium))
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(isSelected ? Color(hex: category.colorHex).opacity(0.25) : Theme.surfaceSunken)
            .foregroundStyle(isSelected ? Color(hex: category.colorHex) : Theme.ink)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(Color(hex: category.colorHex).opacity(isSelected ? 0.6 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
