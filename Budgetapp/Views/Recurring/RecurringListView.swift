import SwiftUI
import SwiftData

struct RecurringListView: View {
    @Environment(\.modelContext) private var context
    @Query private var recurring: [RecurringPayment]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @State private var showingEditor = false
    @State private var showingDetected = false

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }

    private var sorted: [RecurringPayment] {
        recurring.sorted { ($0.isActive ? 0 : 1, $0.nextExpectedDate) < ($1.isActive ? 0 : 1, $1.nextExpectedDate) }
    }

    private var monthlyTotal: Decimal {
        recurring.filter(\.isActive).reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
    }

    var body: some View {
        Group {
            if recurring.isEmpty {
                EmptyStateView(icon: "calendar.badge.clock", title: "No recurring payments",
                               message: "Track rent, subscriptions and bills so they never surprise you.",
                               actionTitle: "Add Recurring", action: { showingEditor = true })
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingDetected = true } label: { Image(systemName: "sparkles") }
                    .accessibilityLabel("Detect recurring")
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add recurring")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack { RecurringEditorView(mode: .create) }
        }
        .sheet(isPresented: $showingDetected) {
            DetectedRecurringView(transactions: transactions, lookups: lookups)
        }
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text("Estimated monthly total").font(.ledgerBody()).foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    Text(CurrencyFormatter.string(monthlyTotal))
                        .font(.ledgerNumber(.body, weight: .bold)).foregroundStyle(Theme.ink)
                }
                .listRowBackground(Theme.surfaceSunken)
            }
            Section {
                ForEach(sorted) { payment in
                    NavigationLink {
                        RecurringEditorView(mode: .edit(payment))
                    } label: {
                        UpcomingRecurringRow(payment: payment, lookups: lookups)
                            .opacity(payment.isActive ? 1 : 0.5)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(payment); try? context.save(); Haptics.tap()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            payment.isActive.toggle(); payment.touch(); try? context.save(); Haptics.selection()
                        } label: {
                            Label(payment.isActive ? "Pause" : "Activate",
                                  systemImage: payment.isActive ? "pause" : "play")
                        }
                        .tint(payment.isActive ? Theme.inkSecondary : Theme.positive)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    private func monthlyEquivalent(_ payment: RecurringPayment) -> Decimal {
        switch payment.frequency {
        case .weekly: return payment.amount * Decimal(52) / 12
        case .biweekly: return payment.amount * Decimal(26) / 12
        case .monthly: return payment.amount
        case .quarterly: return payment.amount / 3
        case .yearly: return payment.amount / 12
        }
    }
}

#Preview {
    NavigationStack { RecurringListView() }
        .modelContainer(PreviewData.container())
}
