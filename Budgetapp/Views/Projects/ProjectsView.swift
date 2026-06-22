import SwiftUI
import SwiftData

/// Manage projects — lightweight tags that group transactions across
/// categories (a trip, a renovation, a side venture). Backs the project picker
/// in the transaction editor.
struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.name) private var projects: [Project]
    @Query private var transactions: [Transaction]

    @State private var showingEditor = false
    @State private var projectToDelete: Project?

    private func usage(_ project: Project) -> Int {
        transactions.filter { $0.projectId == project.id }.count
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                EmptyStateView(icon: "folder", title: "No projects",
                               message: "Group transactions across categories — a trip, a renovation, a side project.",
                               actionTitle: "Add Project", action: { showingEditor = true })
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add project")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack { ProjectEditorView(mode: .create) }
        }
        .confirmationDialog("Delete this project?", isPresented: Binding(
            get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } }
        ), titleVisibility: .visible, presenting: projectToDelete) { project in
            Button("Delete", role: .destructive) {
                DeletionService.deleteProject(project, context: context); Haptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        } message: { project in
            Text(usage(project) > 0
                 ? "\(usage(project)) transaction(s) will be unlinked from this project."
                 : "This can't be undone.")
        }
    }

    private var list: some View {
        List {
            ForEach(projects) { project in
                NavigationLink {
                    ProjectEditorView(mode: .edit(project))
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        Circle().fill(Color(hex: project.colorHex)).frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(project.name).font(.ledgerBody().weight(.medium)).foregroundStyle(Theme.ink)
                            Text(project.isActive ? "\(usage(project)) transaction(s)" : "Archived")
                                .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Theme.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { projectToDelete = project } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }
}

#Preview {
    NavigationStack { ProjectsView() }
        .modelContainer(PreviewData.container())
}
