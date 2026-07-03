import SwiftData
import SwiftUI

struct RecurringPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringPayment.nextExpectedDate) private var payments: [RecurringPayment]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    @State private var showingAddPayment = false
    @State private var editingPayment: RecurringPayment?

    var body: some View {
        List {
            Section("Active") {
                ForEach(payments.filter(\.isActive)) { payment in
                    Button {
                        editingPayment = payment
                    } label: {
                        paymentRow(payment)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            payment.isActive = false
                            payment.touch()
                            try? modelContext.save()
                        } label: {
                            Label("Deactivate", systemImage: "pause.circle")
                        }
                    }
                }
            }

            let inactive = payments.filter { !$0.isActive }
            if !inactive.isEmpty {
                Section("Inactive") {
                    ForEach(inactive) { payment in
                        HStack {
                            Text(payment.name)
                            Spacer()
                            Button("Activate") {
                                payment.isActive = true
                                payment.touch()
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddPayment = true
                } label: {
                    Label("Add Recurring", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPayment) {
            NavigationStack {
                RecurringEditorView(payment: nil)
            }
        }
        .sheet(item: $editingPayment) { payment in
            NavigationStack {
                RecurringEditorView(payment: payment)
            }
        }
    }

    private func paymentRow(_ payment: RecurringPayment) -> some View {
        HStack(spacing: 12) {
            CategoryPill(category: categories.category(id: payment.categoryId))
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.name)
                    .font(.headline)
                Text("\(payment.frequency.label) - next \(AppDateFormatters.short.string(from: payment.nextExpectedDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(MoneyFormatter.string(payment.amount))
                .font(.subheadline.monospacedDigit())
                .privacySensitive()
        }
        .padding(.vertical, 4)
    }
}

struct RecurringEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]

    let payment: RecurringPayment?

    @State private var name: String
    @State private var amount: Decimal
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var frequency: RecurringFrequency
    @State private var nextExpectedDate: Date
    @State private var isActive: Bool

    init(payment: RecurringPayment?) {
        self.payment = payment
        _name = State(initialValue: payment?.name ?? "")
        _amount = State(initialValue: payment?.amount ?? 0)
        _categoryId = State(initialValue: payment?.categoryId)
        _accountId = State(initialValue: payment?.accountId)
        _frequency = State(initialValue: payment?.frequency ?? .monthly)
        _nextExpectedDate = State(initialValue: payment?.nextExpectedDate ?? Date())
        _isActive = State(initialValue: payment?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Payment") {
                TextField("Name", text: $name)
                TextField("Amount", value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { frequency in
                        Text(frequency.label).tag(frequency)
                    }
                }
                DatePicker("Next date", selection: $nextExpectedDate, displayedComponents: .date)
            }

            Section("Classification") {
                Picker("Category", selection: $categoryId) {
                    Text("Unassigned").tag(UUID?.none)
                    ForEach(categories.filter(\.isActive)) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                Picker("Account", selection: $accountId) {
                    Text("No account").tag(UUID?.none)
                    ForEach(accounts.filter(\.isActive)) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                Toggle("Active", isOn: $isActive)
            }
        }
        .navigationTitle(payment == nil ? "New Recurring" : "Edit Recurring")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount <= .zero)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let payment {
            payment.name = cleanName
            payment.amount = amount.absoluteValue
            payment.categoryId = categoryId
            payment.accountId = accountId
            payment.frequency = frequency
            payment.nextExpectedDate = nextExpectedDate
            payment.isActive = isActive
            payment.touch()
        } else {
            modelContext.insert(RecurringPayment(
                name: cleanName,
                amount: amount,
                categoryId: categoryId,
                accountId: accountId,
                frequency: frequency,
                nextExpectedDate: nextExpectedDate,
                isActive: isActive
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
