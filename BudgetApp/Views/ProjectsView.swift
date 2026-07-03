import SwiftData
import SwiftUI

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]

    @State private var showingAddProject = false
    @State private var editingProject: Project?

    var body: some View {
        List {
            Section("Active") {
                ForEach(projects.filter(\.isActive)) { project in
                    Button {
                        editingProject = project
                    } label: {
                        projectRow(project)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            project.isActive = false
                            project.touch()
                            try? modelContext.save()
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }

            let archived = projects.filter { !$0.isActive }
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { project in
                        HStack {
                            Text(project.name)
                            Spacer()
                            Button("Restore") {
                                project.isActive = true
                                project.touch()
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProject = true
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            NavigationStack {
                ProjectEditorView(project: nil)
            }
        }
        .sheet(item: $editingProject) { project in
            NavigationStack {
                ProjectEditorView(project: project)
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        let spent = monthlySpend(for: project)
        let remaining = project.monthlyBudget - spent
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(project.name, systemImage: "folder.fill")
                    .font(.headline)
                    .foregroundStyle(remaining < .zero ? BudgetTheme.rust : BudgetTheme.ink)
                Spacer()
                Text(MoneyFormatter.string(spent))
                    .font(.subheadline.monospacedDigit())
                    .privacySensitive()
            }
            ProgressLine(
                percent: project.monthlyBudget > .zero ? min(1.25, spent.doubleValue / project.monthlyBudget.doubleValue) : 0,
                tint: remaining < .zero ? BudgetTheme.rust : BudgetTheme.ink
            )
            HStack {
                Text(project.monthlyBudget > .zero ? "of \(MoneyFormatter.string(project.monthlyBudget))" : "No project budget")
                    .privacySensitive(project.monthlyBudget > .zero)
                Spacer()
                Text(remaining >= .zero ? "\(MoneyFormatter.string(remaining)) left" : "\(MoneyFormatter.string(remaining.absoluteValue)) over")
                    .foregroundStyle(remaining < .zero ? BudgetTheme.rust : .secondary)
                    .privacySensitive()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func monthlySpend(for project: Project) -> Decimal {
        let interval = BudgetMath.monthInterval(containing: Date())
        return transactions
            .filter { $0.projectId == project.id && $0.type == .expense && BudgetMath.isDate($0.date, inside: interval) }
            .reduce(.zero) { $0 + $1.amount }
    }
}

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let project: Project?
    @State private var name: String
    @State private var colorHex: String
    @State private var monthlyBudget: Decimal
    @State private var isActive: Bool

    private let swatches = ["#0E0B09", "#750609", "#F7EFE2"]

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _colorHex = State(initialValue: project?.colorHex ?? "#750609")
        _monthlyBudget = State(initialValue: project?.monthlyBudget ?? 0)
        _isActive = State(initialValue: project?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Project") {
                TextField("Name", text: $name)
                HStack {
                    Text("Monthly Budget")
                    Spacer()
                    TextField("0", value: $monthlyBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Active", isOn: $isActive)
            }

            Section("Color") {
                HStack {
                    ForEach(swatches, id: \.self) { swatch in
                        Button {
                            colorHex = swatch
                        } label: {
                            Circle()
                                .fill(Color(hex: swatch))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if colorHex == swatch {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(swatch == "#F7EFE2" ? BudgetTheme.ink : .white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(project == nil ? "New Project" : "Edit Project")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let project {
            project.name = cleanName
            project.colorHex = colorHex
            project.monthlyBudget = max(.zero, monthlyBudget)
            project.isActive = isActive
            project.touch()
        } else {
            modelContext.insert(Project(name: cleanName, colorHex: colorHex, monthlyBudget: max(.zero, monthlyBudget), isActive: isActive))
        }
        try? modelContext.save()
        dismiss()
    }
}
