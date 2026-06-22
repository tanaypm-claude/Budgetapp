import SwiftUI
import SwiftData

/// Hub for the secondary destinations: management screens, rules, review, and
/// settings. Keeps the main tab bar uncluttered.
struct MoreView: View {
    @Query private var transactions: [Transaction]
    private var reviewCount: Int { transactions.filter { !$0.isReviewed }.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ReviewQueueView()
                    } label: {
                        moreRow("tray.full", "Review Queue", tint: Theme.warning, badge: reviewCount)
                    }
                }

                Section("Manage") {
                    NavigationLink { CategoriesView() } label: { moreRow("tag.fill", "Categories", tint: Theme.accent) }
                    NavigationLink { AccountsListView() } label: { moreRow("building.columns.fill", "Accounts", tint: Color(hex: "#4C8CB5")) }
                    NavigationLink { RecurringListView() } label: { moreRow("calendar.badge.clock", "Recurring", tint: Color(hex: "#9C6B9E")) }
                    NavigationLink { ProjectsView() } label: { moreRow("folder.fill", "Projects", tint: Color(hex: "#5E7CE2")) }
                    NavigationLink { RulesListView() } label: { moreRow("wand.and.stars", "Import Rules", tint: Color(hex: "#6BB0A4")) }
                }

                Section("App") {
                    NavigationLink { SettingsView() } label: { moreRow("gearshape.fill", "Settings & Data", tint: Theme.inkSecondary) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("More")
        }
    }

    private func moreRow(_ icon: String, _ title: String, tint: Color, badge: Int = 0) -> some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: icon)
                .font(.body).foregroundStyle(tint).frame(width: 30)
            Text(title).font(.ledgerBody()).foregroundStyle(Theme.ink)
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .font(.ledgerCaption().weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.warning).clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MoreView()
        .modelContainer(PreviewData.container())
}
