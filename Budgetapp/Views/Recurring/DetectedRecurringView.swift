import SwiftUI

/// Surfaces likely recurring expenses detected from history and lets the user
/// promote any of them into a tracked `RecurringPayment`.
struct DetectedRecurringView: View {
    @Environment(\.dismiss) private var dismiss
    let transactions: [Transaction]
    let lookups: Lookups

    @State private var selectedCandidate: RecurringCandidate? = nil

    private var candidates: [RecurringCandidate] {
        RecurringDetector.detect(transactions: transactions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    EmptyStateView(icon: "sparkles", title: "Nothing detected yet",
                                   message: "Once you have a few months of similar charges, suggestions appear here.")
                } else {
                    List(candidates) { candidate in
                        Button {
                            selectedCandidate = candidate
                        } label: {
                            HStack(spacing: Theme.Space.md) {
                                let category = lookups.category(candidate.categoryId)
                                CategoryGlyph(symbol: category?.symbol ?? "repeat",
                                              colorHex: category?.colorHex ?? "#5E7CE2", size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(candidate.displayName)
                                        .font(.ledgerBody().weight(.medium)).foregroundStyle(Theme.ink)
                                    Text("\(candidate.frequency.label) · seen \(candidate.occurrences)×")
                                        .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                                }
                                Spacer()
                                Text(CurrencyFormatter.compact(candidate.typicalAmount))
                                    .font(.ledgerNumber(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                                Image(systemName: "plus.circle").foregroundStyle(Theme.accent)
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Theme.paper)
                }
            }
            .background(Theme.paper)
            .navigationTitle("Detected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(item: $selectedCandidate) { candidate in
                NavigationStack { RecurringEditorView(mode: .createFrom(candidate)) }
            }
        }
    }
}
