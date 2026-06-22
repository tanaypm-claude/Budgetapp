import SwiftUI

/// Shown when the persistent store can't be opened (corrupt/incompatible).
/// Rather than silently running on a throwaway in-memory store, we explain the
/// problem and offer explicit recovery: retry, or reset the local store.
struct StoreRecoveryView: View {
    let error: Error
    let onRetry: () -> Void

    @State private var showingResetConfirm = false
    @State private var resetMessage: String?

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.warning)

            Text("Can't open your data")
                .font(.ledgerTitle())
                .foregroundStyle(Theme.ink)

            Text("The local database couldn't be loaded, so the app hasn't started. Your data hasn't been changed. You can try again, or reset the local store to start fresh.")
                .font(.ledgerBody())
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)

            Text(error.localizedDescription)
                .font(.ledgerCaption())
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)

            Spacer()

            VStack(spacing: Theme.Space.md) {
                Button(action: onRetry) {
                    Text("Try Again").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    Text("Reset Local Data").frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Text("Reset permanently deletes the on-device store. There's no cloud copy, so only do this if you can't recover.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .confirmationDialog("Reset local data?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Delete & Reset", role: .destructive) { performReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local database and cannot be undone.")
        }
        .alert("Reset failed", isPresented: Binding(
            get: { resetMessage != nil }, set: { if !$0 { resetMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(resetMessage ?? "") }
    }

    private func performReset() {
        do {
            try PersistenceController.resetStore()
            Haptics.warning()
            onRetry()
        } catch {
            resetMessage = error.localizedDescription
        }
    }
}
