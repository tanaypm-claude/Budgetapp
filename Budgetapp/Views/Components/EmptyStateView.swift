import SwiftUI

/// Friendly empty state with an icon, message, and optional action — used
/// wherever a list might be empty so the app never shows a blank void.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.inkFaint)
            Text(title)
                .font(.ledgerHeadline())
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.ledgerCaption())
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }
}
