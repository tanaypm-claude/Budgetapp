import SwiftUI
import SwiftData

/// Top-level tab navigation. Seeds defaults on first appearance.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]

    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, ledger, importer, reports, more
    }

    var unreviewedCount: Int {
        transactions.filter { !$0.isReviewed }.count
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            TransactionsView()
                .tabItem { Label("Ledger", systemImage: "list.bullet.rectangle.portrait") }
                .tag(Tab.ledger)

            ImportLandingView()
                .tabItem { Label("Import", systemImage: "tray.and.arrow.down") }
                .tag(Tab.importer)

            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.xaxis") }
                .tag(Tab.reports)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
                .badge(unreviewedCount)
        }
        .onAppear { SeedData.seedIfNeeded(context: context) }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container())
}
