import SwiftUI
import SwiftData

struct RulesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ImportRule.priority) private var rules: [ImportRule]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var showingEditor = false
    @State private var ruleToDelete: ImportRule?

    private var lookups: Lookups { Lookups(categories: categories, accounts: accounts) }

    var body: some View {
        Group {
            if rules.isEmpty {
                EmptyStateView(icon: "wand.and.stars", title: "No rules yet",
                               message: "Rules auto-categorise imports. e.g. merchant contains “Swiggy” → Food.",
                               actionTitle: "Add Rule", action: { showingEditor = true })
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle("Import Rules")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add rule")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack { RuleEditorView(mode: .create) }
        }
        .confirmationDialog("Delete this rule?", isPresented: Binding(
            get: { ruleToDelete != nil }, set: { if !$0 { ruleToDelete = nil } }
        ), titleVisibility: .visible, presenting: ruleToDelete) { rule in
            Button("Delete", role: .destructive) {
                context.delete(rule); try? context.save(); Haptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(rules) { rule in
                    NavigationLink {
                        RuleEditorView(mode: .edit(rule))
                    } label: {
                        RuleRow(rule: rule, lookups: lookups)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            ruleToDelete = rule
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } footer: {
                Text("Rules apply top to bottom by priority. The first match wins.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }
}

struct RuleRow: View {
    let rule: ImportRule
    let lookups: Lookups

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            let category = lookups.category(rule.categoryId)
            CategoryGlyph(symbol: category?.symbol ?? "tag", colorHex: category?.colorHex ?? "#9A9384", size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name.isEmpty ? rule.matchValue : rule.name)
                    .font(.ledgerBody().weight(.medium)).foregroundStyle(Theme.ink)
                Text("\(rule.matchField.label) \(rule.matchType.label.lowercased()) “\(rule.matchValue)” → \(lookups.categoryName(rule.categoryId))")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary).lineLimit(2)
            }
            Spacer()
            if !rule.isActive {
                Image(systemName: "pause.circle").foregroundStyle(Theme.inkFaint)
            }
            Text("#\(rule.priority)").font(.ledgerCaption()).foregroundStyle(Theme.inkFaint)
        }
        .padding(.vertical, 2)
    }
}
