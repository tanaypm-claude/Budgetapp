import SwiftUI

struct MoreView: View {
    var body: some View {
        List {
            Section("Workspace") {
                NavigationLink {
                    ReportsView()
                } label: {
                    Label("Expanded Reports", systemImage: "chart.bar.xaxis")
                }
                NavigationLink {
                    TransactionsView()
                } label: {
                    Label("Ledger", systemImage: "list.bullet.rectangle")
                }
                NavigationLink {
                    ImportHubView()
                } label: {
                    Label("Import and Review", systemImage: "tray.and.arrow.down")
                }
                NavigationLink {
                    TabBarCustomizationView()
                } label: {
                    Label("Dock", systemImage: "slider.horizontal.3")
                }
            }

            Section("Budget Setup") {
                NavigationLink {
                    AccountsView()
                } label: {
                    Label("Accounts", systemImage: "building.columns")
                }
                NavigationLink {
                    RecurringPaymentsView()
                } label: {
                    Label("Recurring Payments", systemImage: "calendar.badge.clock")
                }
                NavigationLink {
                    ProjectsView()
                } label: {
                    Label("Projects", systemImage: "folder")
                }
                NavigationLink {
                    RulesView()
                } label: {
                    Label("Smart Rules", systemImage: "wand.and.stars")
                }
            }

            Section("Data") {
                NavigationLink {
                    DataSafetyView()
                } label: {
                    Label("Backup, Restore, Export", systemImage: "externaldrive")
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Studio")
    }
}

struct TabBarCustomizationView: View {
    @AppStorage(AppTab.storageKey) private var visibleTabsRaw = AppTab.encode(AppTab.defaultTabs)

    private var visibleTabs: [AppTab] {
        AppTab.decode(visibleTabsRaw)
    }

    var body: some View {
        List {
            Section {
                ForEach(AppTab.allCases) { tab in
                    Toggle(isOn: binding(for: tab)) {
                        Label(tab.title, systemImage: tab.symbol)
                    }
                    .disabled(tab == .more)
                }
            } header: {
                Text("Visible Tabs")
            } footer: {
                Text("Studio stays visible so customization is always recoverable.")
            }

            Section {
                ForEach(visibleTabs) { tab in
                    Label(tab.title, systemImage: tab.symbol)
                }
                .onMove(perform: moveTabs)
            } header: {
                Text("Order")
            }
        }
        .tactileListBackground()
        .navigationTitle("Dock")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Reset") {
                    visibleTabsRaw = AppTab.encode(AppTab.defaultTabs)
                }
            }
        }
    }

    private func binding(for tab: AppTab) -> Binding<Bool> {
        Binding(
            get: { visibleTabs.contains(tab) },
            set: { isVisible in
                var tabs = visibleTabs
                if isVisible {
                    if !tabs.contains(tab) {
                        let insertIndex = max(0, tabs.count - 1)
                        tabs.insert(tab, at: insertIndex)
                    }
                } else if tab != .more {
                    tabs.removeAll { $0 == tab }
                }
                visibleTabsRaw = AppTab.encode(tabs)
            }
        )
    }

    private func moveTabs(from source: IndexSet, to destination: Int) {
        var tabs = visibleTabs
        tabs.move(fromOffsets: source, toOffset: destination)
        if !tabs.contains(.more) {
            tabs.append(.more)
        }
        visibleTabsRaw = AppTab.encode(tabs)
    }
}
