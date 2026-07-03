import SwiftUI

struct CSVColumnMappingView: View {
    @Environment(\.dismiss) private var dismiss

    let document: CSVDocument
    let onContinue: (CSVColumnMapping) -> Void

    @State private var mapping: CSVColumnMapping

    init(document: CSVDocument, onContinue: @escaping (CSVColumnMapping) -> Void) {
        self.document = document
        self.onContinue = onContinue
        _mapping = State(initialValue: document.detectedMapping)
    }

    var body: some View {
        Form {
            Section("Required") {
                columnPicker("Date", selection: $mapping.date)
                columnPicker("Merchant", selection: $mapping.merchant)
                columnPicker("Description", selection: $mapping.narration)
                columnPicker("Debit", selection: $mapping.debit)
                columnPicker("Credit", selection: $mapping.credit)
                columnPicker("Amount", selection: $mapping.amount)
            }

            Section("Optional") {
                columnPicker("Account", selection: $mapping.account)
                columnPicker("Category", selection: $mapping.category)
            }

            Section("Sample") {
                ForEach(document.rows.prefix(4).indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Row \(index + 2)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(sampleLine(document.rows[index]))
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle("Map Columns")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Preview") {
                    onContinue(mapping)
                    dismiss()
                }
                .disabled(!mapping.requiredFieldsMapped)
            }
        }
    }

    @ViewBuilder
    private func columnPicker(_ title: String, selection: Binding<String?>) -> some View {
        Picker(title, selection: selection) {
            Text("Not mapped").tag(String?.none)
            ForEach(document.headers, id: \.self) { header in
                Text(header).tag(Optional(header))
            }
        }
    }

    private func sampleLine(_ row: [String]) -> String {
        zip(document.headers, row).map { "\($0): \($1)" }.joined(separator: " | ")
    }
}
