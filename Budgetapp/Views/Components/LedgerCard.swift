import SwiftUI

/// A raised "card" surface with a soft border, used to group related content.
/// Deliberately understated — no heavy shadows — to keep the ledger feel.
struct LedgerCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

/// A small uppercase section label with optional trailing accessory.
struct SectionLabel<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    init(_ title: String, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.ledgerCaption().weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            accessory
        }
    }
}
