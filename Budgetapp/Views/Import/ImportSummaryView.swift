import SwiftUI

/// Confirmation shown after a successful import.
struct ImportSummaryView: View {
    let batch: ImportBatch
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundStyle(Theme.positive)
            Text("Imported").font(.ledgerTitle()).foregroundStyle(Theme.ink)
            VStack(spacing: 4) {
                Text("\(batch.rowCount) transactions saved")
                    .font(.ledgerBody()).foregroundStyle(Theme.ink)
                if batch.duplicateCount > 0 {
                    Text("\(batch.duplicateCount) duplicates skipped")
                        .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                }
                if batch.needsReviewCount > 0 {
                    Text("\(batch.needsReviewCount) need review")
                        .font(.ledgerCaption()).foregroundStyle(Theme.warning)
                }
            }
            Spacer()
            Button(action: onDone) {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Theme.Space.xl)
        }
        .padding(.bottom, Theme.Space.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
        .navigationBarBackButtonHidden(true)
    }
}
