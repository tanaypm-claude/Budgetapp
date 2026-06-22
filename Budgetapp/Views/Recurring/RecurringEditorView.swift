import SwiftUI
import SwiftData

struct RecurringEditorView: View {
    enum Mode { case create, edit(RecurringPayment), createFrom(RecurringCandidate) }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let mode: Mode

    @State private var name = ""
    @State private var amountString = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var nextDate = Date.now
    @State private var categoryId: UUID? = nil
    @State private var accountId: UUID? = nil
    @State private var isActive = true
    @State private var note = ""
    @State private var didLoad = false
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (ValueParsing.parseAmount(amountString) ?? 0) > 0
    }

    var body: some View {
        Form {
            Section {
                TextField("Name (e.g. Rent, Netflix)", text: $name).textInputAutocapitalization(.words)
                HStack {
                    Text(AppSettings.currencySymbol).foregroundStyle(Theme.inkSecondary)
                    TextField("0", text: $amountString).keyboardType(.decimalPad)
                        .font(.ledgerNumber(.title3, weight: .semibold))
                }
            }
            Section("Schedule") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { Text($0.label).tag($0) }
                }
                DatePicker("Next expected", selection: $nextDate, displayedComponents: .date)
            }
            Section("Classification") {
                Picker("Category", selection: $categoryId) {
                    Text("None").tag(UUID?.none)
                    ForEach(categories.filter(\.isActive)) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
                }
                Picker("Account", selection: $accountId) {
                    Text("None").tag(UUID?.none)
                    ForEach(accounts.filter(\.isActive)) { Label($0.name, systemImage: $0.type.symbolName).tag(Optional($0.id)) }
                }
            }
            Section("Note") {
                TextField("Optional", text: $note, axis: .vertical).lineLimit(1...3)
            }
            if isEditing {
                Section {
                    Toggle("Active", isOn: $isActive)
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(isEditing ? "Edit Recurring" : "New Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
        }
        .confirmationDialog("Delete this recurring payment?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deletePayment() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        switch mode {
        case .create:
            accountId = accounts.first(where: \.isActive)?.id
        case let .edit(payment):
            name = payment.name
            amountString = NSDecimalNumber(decimal: payment.amount).stringValue
            frequency = payment.frequency
            nextDate = payment.nextExpectedDate
            categoryId = payment.categoryId
            accountId = payment.accountId
            isActive = payment.isActive
            note = payment.note
        case let .createFrom(candidate):
            name = candidate.displayName
            amountString = NSDecimalNumber(decimal: candidate.typicalAmount).stringValue
            frequency = candidate.frequency
            nextDate = candidate.suggestedNextDate
            categoryId = candidate.categoryId
            accountId = accounts.first(where: \.isActive)?.id
        }
    }

    private func save() {
        let amount = ValueParsing.parseAmount(amountString) ?? 0
        if case let .edit(payment) = mode {
            payment.name = name.trimmed
            payment.amount = amount
            payment.frequency = frequency
            payment.nextExpectedDate = nextDate
            payment.categoryId = categoryId
            payment.accountId = accountId
            payment.isActive = isActive
            payment.note = note.trimmed
            payment.touch()
        } else {
            let payment = RecurringPayment(name: name.trimmed, amount: amount, categoryId: categoryId,
                                           accountId: accountId, frequency: frequency, nextExpectedDate: nextDate,
                                           note: note.trimmed)
            context.insert(payment)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func deletePayment() {
        if case let .edit(payment) = mode {
            context.delete(payment); try? context.save(); Haptics.warning(); dismiss()
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
