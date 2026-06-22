import SwiftUI
import SwiftData

struct ProjectEditorView: View {
    enum Mode { case create, edit(Project) }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name = ""
    @State private var colorHex = CategoryPalette.colors.first ?? "#5E7CE2"
    @State private var isActive = true
    @State private var didLoad = false
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Theme.Space.md) {
                    Circle().fill(Color(hex: colorHex)).frame(width: 28, height: 28)
                    TextField("Project name", text: $name)
                        .font(.ledgerHeadline())
                        .textInputAutocapitalization(.words)
                }
            }

            Section("Colour") {
                ColorSwatchPicker(selection: $colorHex)
            }

            if isEditing {
                Section {
                    Toggle("Active", isOn: $isActive)
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete project", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Deleting unlinks it from any transactions but keeps the transactions themselves.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(isEditing ? "Edit Project" : "New Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
        }
        .confirmationDialog("Delete this project?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteProject() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if case let .edit(project) = mode {
            name = project.name
            colorHex = project.colorHex
            isActive = project.isActive
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if case let .edit(project) = mode {
            project.name = trimmed
            project.colorHex = colorHex
            project.isActive = isActive
            project.touch()
        } else {
            context.insert(Project(name: trimmed, colorHex: colorHex))
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func deleteProject() {
        if case let .edit(project) = mode {
            DeletionService.deleteProject(project, context: context)
            Haptics.warning()
            dismiss()
        }
    }
}
