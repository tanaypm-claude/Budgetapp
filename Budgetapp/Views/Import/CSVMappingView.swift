import SwiftUI
import SwiftData

/// Column-mapping step for CSV imports: shows detected headers with a sample
/// value and lets the user assign each to a role. Continues to the preview.
struct CSVMappingView: View {
    @Environment(\.modelContext) private var context
    let session: ImportService.CSVSession
    let onCancel: () -> Void

    @State private var mapping: ColumnMapping
    @State private var preview: ImportPreview? = nil
    @State private var errorMessage: String? = nil

    init(session: ImportService.CSVSession, onCancel: @escaping () -> Void) {
        self.session = session
        self.onCancel = onCancel
        _mapping = State(initialValue: session.mapping)
    }

    private var sampleRow: [String] { session.table.rows.first ?? [] }

    var body: some View {
        Form {
            Section {
                Text("\(session.table.rows.count) rows · \(session.table.headers.count) columns")
                    .font(.ledgerCaption()).foregroundStyle(Theme.inkSecondary)
            } header: {
                Text(session.filename)
            }

            Section("Map columns") {
                ForEach(session.table.headers.indices, id: \.self) { index in
                    let header = session.table.headers[index]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(header.isEmpty ? "Column \(index + 1)" : header)
                                .font(.ledgerBody().weight(.medium)).foregroundStyle(Theme.ink)
                            if index < sampleRow.count, !sampleRow[index].isEmpty {
                                Text(sampleRow[index]).font(.ledgerCaption())
                                    .foregroundStyle(Theme.inkFaint).lineLimit(1)
                            }
                        }
                        Spacer()
                        Picker("", selection: roleBinding(for: header)) {
                            ForEach(CSVColumnRole.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
            }

            if let message = mapping.validationMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.ledgerCaption()).foregroundStyle(Theme.warning)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("Map Columns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel", action: onCancel) }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Preview") { buildPreview() }
                    .disabled(!mapping.isValid).fontWeight(.semibold)
            }
        }
        .navigationDestination(item: $preview) { preview in
            ImportPreviewView(preview: preview, onClose: onCancel)
        }
        .alert("Couldn't map", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    /// Two-way binding between a header's current role and the picker. Assigning
    /// a role to one header clears it from any other (each role maps once).
    private func roleBinding(for header: String) -> Binding<CSVColumnRole> {
        Binding(
            get: {
                mapping.assignments.first(where: { $0.value == header })?.key ?? .ignore
            },
            set: { newRole in
                // Remove this header from any existing role.
                for (role, value) in mapping.assignments where value == header {
                    mapping.assignments[role] = nil
                }
                if newRole != .ignore {
                    // Ensure the role is unique to this header.
                    mapping.assignments[newRole] = header
                }
                Haptics.selection()
            }
        )
    }

    private func buildPreview() {
        let service = ImportService(context: context)
        do {
            preview = try service.makeCSVPreview(table: session.table, mapping: mapping, filename: session.filename)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// Allow ImportPreview to drive `navigationDestination(item:)`.
extension ImportPreview: Identifiable, Hashable {
    var id: String { filename + "-" + String(transactions.count) }
    static func == (lhs: ImportPreview, rhs: ImportPreview) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
