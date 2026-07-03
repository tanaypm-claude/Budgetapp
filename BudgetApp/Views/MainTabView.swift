import SwiftData
import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case categories
    case reports
    case ledger
    case importReview
    case accounts
    case projects
    case recurring
    case rules
    case data
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Today"
        case .categories: "Categories"
        case .reports: "Reports"
        case .ledger: "Ledger"
        case .importReview: "Review"
        case .accounts: "Accounts"
        case .projects: "Projects"
        case .recurring: "Recurring"
        case .rules: "Rules"
        case .data: "Data"
        case .more: "Studio"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .categories: "tag.fill"
        case .reports: "chart.pie.fill"
        case .ledger: "list.bullet.rectangle"
        case .importReview: "tray.and.arrow.down.fill"
        case .accounts: "building.columns.fill"
        case .projects: "folder.fill"
        case .recurring: "calendar.badge.clock"
        case .rules: "wand.and.stars"
        case .data: "externaldrive.fill"
        case .more: "ellipsis.circle"
        }
    }

    static let storageKey = "kosha.visibleTabs"
    static let defaultTabs: [AppTab] = [.dashboard, .categories, .more]

    static func decode(_ raw: String) -> [AppTab] {
        let decoded = raw
            .split(separator: ",")
            .compactMap { tab(from: String($0)) }
        let base = decoded.isEmpty ? defaultTabs : decoded
        let unique = base.reduce(into: [AppTab]()) { result, tab in
            if !result.contains(tab) {
                result.append(tab)
            }
        }
        return unique.contains(.more) ? unique : unique + [.more]
    }

    static func encode(_ tabs: [AppTab]) -> String {
        tabs.map(\.rawValue).joined(separator: ",")
    }

    private static func tab(from raw: String) -> AppTab? {
        switch raw {
        case "inbox", "import": .importReview
        default: AppTab(rawValue: raw)
        }
    }
}

enum QuickActionSheet: Identifiable {
    case transaction
    case importStatement

    var id: String {
        switch self {
        case .transaction: "transaction"
        case .importStatement: "importStatement"
        }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppTab.storageKey) private var visibleTabsRaw = AppTab.encode(AppTab.defaultTabs)
    @State private var selection: AppTab = .dashboard
    @State private var activeQuickAction: QuickActionSheet?
    @State private var quickButtonOffset: CGSize = .zero
    @State private var quickButtonDragStartOffset: CGSize = .zero

    private var visibleTabs: [AppTab] {
        AppTab.decode(visibleTabsRaw)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(visibleTabs) { tab in
                NavigationStack {
                    content(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.symbol)
                }
                .tag(tab)
            }
        }
        .tint(BudgetTheme.rust)
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            quickActionButton
                .padding(.trailing, 18)
                .padding(.bottom, 12)
                .offset(clampedQuickButtonOffset(quickButtonOffset))
                .onAppear {
                    let clampedOffset = clampedQuickButtonOffset(quickButtonOffset)
                    quickButtonOffset = clampedOffset
                    quickButtonDragStartOffset = clampedOffset
                }
        }
        .sheet(item: $activeQuickAction) { action in
            NavigationStack {
                switch action {
                case .transaction:
                    TransactionEditorView(transaction: nil)
                case .importStatement:
                    ImportHubView()
                }
            }
        }
        .onChange(of: visibleTabsRaw) { _, _ in
            if !visibleTabs.contains(selection) {
                selection = visibleTabs.first ?? .dashboard
            }
        }
        .task {
            SeedDataService.seedIfNeeded(in: modelContext)
        }
    }

    private var quickActionButton: some View {
        Menu {
            Button {
                activeQuickAction = .transaction
            } label: {
                Label("Add Transaction", systemImage: "plus.circle")
            }
            Button {
                activeQuickAction = .importStatement
            } label: {
                Label("Import Statement", systemImage: "doc.badge.plus")
            }
        } label: {
            quickActionButtonLabel
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let proposed = CGSize(
                        width: quickButtonDragStartOffset.width + value.translation.width,
                        height: quickButtonDragStartOffset.height + value.translation.height
                    )
                    quickButtonOffset = clampedQuickButtonOffset(proposed)
                }
                .onEnded { _ in
                    quickButtonDragStartOffset = quickButtonOffset
                }
        )
        .accessibilityLabel("Quick add")
    }

    private var quickActionButtonLabel: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            BudgetTheme.lightBlue.opacity(0.48),
                            BudgetTheme.green.opacity(0.22),
                            BudgetTheme.yellow.opacity(0.18),
                            Color.white.opacity(0.24),
                            BudgetTheme.lightBlue.opacity(0.48)
                        ],
                        center: .center
                    )
                )
                .blendMode(.screen)
                .opacity(0.88)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.44),
                            Color.white.opacity(0.10),
                            BudgetTheme.blue.opacity(0.18)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 64
                    )
                )
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.82),
                            BudgetTheme.lightBlue.opacity(0.34),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            Circle()
                .fill(Color.white.opacity(0.42))
                .frame(width: 18, height: 10)
                .blur(radius: 8)
                .offset(x: -12, y: -16)
            Image(systemName: "plus")
                .font(.title.weight(.black))
                .foregroundStyle(BudgetTheme.ink)
                .shadow(color: Color.white.opacity(0.45), radius: 5, x: 0, y: 0)
        }
        .frame(width: 62, height: 62)
        .contentShape(Circle())
        .shadow(color: BudgetTheme.lightBlue.opacity(0.36), radius: 16, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 10)
    }

    private func clampedQuickButtonOffset(_ proposed: CGSize) -> CGSize {
        let screen = UIScreen.main.bounds
        let horizontalLimit = max(0, screen.width - 98)
        let verticalLimit = max(0, screen.height - 202)

        return CGSize(
            width: min(0, max(-horizontalLimit, proposed.width)),
            height: min(0, max(-verticalLimit, proposed.height))
        )
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            HomeView()
        case .categories:
            CategoriesView()
        case .reports:
            ReportsView()
        case .ledger:
            TransactionsView()
        case .importReview:
            ImportHubView()
        case .accounts:
            AccountsView()
        case .projects:
            ProjectsView()
        case .recurring:
            RecurringPaymentsView()
        case .rules:
            RulesView()
        case .data:
            DataSafetyView()
        case .more:
            MoreView()
        }
    }
}
