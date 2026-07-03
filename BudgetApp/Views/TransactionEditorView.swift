import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import Vision

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \ImportRule.priority) private var rules: [ImportRule]

    let transaction: BudgetTransaction?

    @State private var date: Date
    @State private var merchant: String
    @State private var narration: String
    @State private var amountDigits: String
    @State private var type: TransactionType
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var projectId: UUID?
    @State private var note: String
    @State private var isReviewed: Bool
    @State private var receiptItem: PhotosPickerItem?
    @State private var receiptStatus = "Read receipt"

    private let keypadRows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["00", "0", "delete.left"]
    ]

    init(transaction: BudgetTransaction?) {
        self.transaction = transaction
        _date = State(initialValue: transaction?.date ?? Date())
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _narration = State(initialValue: transaction?.narration ?? "")
        _amountDigits = State(initialValue: Self.digits(from: transaction?.amount ?? .zero))
        _type = State(initialValue: transaction?.type ?? .expense)
        _categoryId = State(initialValue: transaction?.categoryId)
        _accountId = State(initialValue: transaction?.accountId)
        _projectId = State(initialValue: transaction?.projectId)
        _note = State(initialValue: transaction?.note ?? "")
        _isReviewed = State(initialValue: transaction?.isReviewed ?? true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                amountStage
                smartRuleStage
                detailStage
                sortingStage
                receiptStage
                noteStage
            }
            .padding()
        }
        .budgetScreenBackground()
        .navigationTitle(transaction == nil ? "New Spend" : "Edit Spend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(cleanMerchant.isEmpty || amountValue <= .zero)
            }
        }
        .onChange(of: receiptItem) { _, newItem in
            Task { await readReceipt(newItem) }
        }
    }

    private var amountStage: some View {
        LedgerPanel(title: nil, subtitle: nil) {
            VStack(alignment: .leading, spacing: 18) {
                Text(MoneyFormatter.string(amountValue))
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.52)
                    .lineLimit(1)
                    .foregroundStyle(BudgetTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .privacySensitive()

                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 10) {
                    ForEach(keypadRows, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { key in
                                keypadButton(key)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var smartRuleStage: some View {
        if let suggestedRule {
            Button {
                accept(rule: suggestedRule)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(BudgetTheme.yellow)
                        .frame(width: 34, height: 34)
                        .background(BudgetTheme.yellow.opacity(0.18), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Smart sort found")
                            .font(.headline)
                            .foregroundStyle(BudgetTheme.ink)
                        Text(ruleSummary(suggestedRule))
                            .font(.caption)
                            .foregroundStyle(BudgetTheme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BudgetTheme.green)
                }
                .padding(14)
                .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accept smart rule \(suggestedRule.name)")
        }
    }

    private var detailStage: some View {
        LedgerPanel(title: "Place", subtitle: "Name first, notes second") {
            VStack(spacing: 12) {
                TextField("Merchant or place", text: $merchant)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .padding(12)
                    .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("What was it for?", text: $narration, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .padding(12)
                    .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHint("Captured automatically, but editable")
            }
        }
    }

    private var sortingStage: some View {
        LedgerPanel(title: "Sort", subtitle: "Rules can fill this, you can override it") {
            VStack(spacing: 12) {
                menuPicker(title: "Category", value: categories.category(id: categoryId)?.name ?? "Unassigned") {
                    Button("Unassigned") { categoryId = nil }
                    ForEach(categories.filter(\.isActive)) { category in
                        Button {
                            categoryId = category.id
                            isReviewed = true
                        } label: {
                            Label(category.name, systemImage: category.symbol)
                        }
                    }
                }

                menuPicker(title: "Account", value: accounts.account(id: accountId)?.name ?? "No account") {
                    Button("No account") { accountId = nil }
                    ForEach(accounts.filter(\.isActive)) { account in
                        Button(account.name) { accountId = account.id }
                    }
                }

                menuPicker(title: "Project", value: projects.first(where: { $0.id == projectId })?.name ?? "No project") {
                    Button("No project") { projectId = nil }
                    ForEach(projects.filter(\.isActive)) { project in
                        Button(project.name) { projectId = project.id }
                    }
                }

                Toggle("Reviewed", isOn: $isReviewed)
                    .tint(BudgetTheme.green)
            }
        }
    }

    private var receiptStage: some View {
        LedgerPanel(title: "Receipt", subtitle: "Image text is read on-device") {
            PhotosPicker(selection: $receiptItem, matching: .images) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.viewfinder")
                        .foregroundStyle(BudgetTheme.blue)
                        .frame(width: 34, height: 34)
                        .background(BudgetTheme.blue.opacity(0.18), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(receiptStatus)
                            .font(.headline)
                            .foregroundStyle(BudgetTheme.ink)
                        Text("Amount, merchant and date suggestions fill the fields above.")
                            .font(.caption)
                            .foregroundStyle(BudgetTheme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(BudgetTheme.lightBlue)
                }
                .padding(14)
                .background(BudgetTheme.tile, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var noteStage: some View {
        LedgerPanel(title: "Private Note", subtitle: nil) {
            TextField("Anything Tanay should remember?", text: $note, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func keypadButton(_ key: String) -> some View {
        Button {
            handleKey(key)
        } label: {
            Group {
                if key == "delete.left" {
                    Image(systemName: key)
                } else {
                    Text(key)
                }
            }
            .font(.title2.weight(.bold))
            .foregroundStyle(BudgetTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(key == "delete.left" ? BudgetTheme.red.opacity(0.22) : BudgetTheme.lifted, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key == "delete.left" ? "Delete digit" : key)
    }

    private func menuPicker<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(BudgetTheme.secondaryInk)
                Spacer()
                Text(value)
                    .foregroundStyle(BudgetTheme.ink)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BudgetTheme.secondaryInk)
            }
            .padding(12)
            .background(BudgetTheme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var cleanMerchant: String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amountValue: Decimal {
        guard !amountDigits.isEmpty, let cents = Decimal(string: amountDigits) else { return .zero }
        return (cents / Decimal(100)).roundedToPaise
    }

    private var suggestedRule: ImportRule? {
        guard !cleanMerchant.isEmpty || !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let draft = DraftTransaction(
            date: date,
            merchant: cleanMerchant,
            narration: narration,
            amount: amountValue,
            type: type,
            source: .manual,
            isReviewed: isReviewed
        )
        guard let rule = RulesEngine.matchingRule(for: draft, rules: rules) else { return nil }
        if rule.categoryId == categoryId && rule.accountId == accountId { return nil }
        return rule
    }

    private func handleKey(_ key: String) {
        if key == "delete.left" {
            if !amountDigits.isEmpty {
                amountDigits.removeLast()
            }
            return
        }
        guard amountDigits.count < 12 else { return }
        amountDigits.append(contentsOf: key)
        trimLeadingZeroes()
    }

    private func trimLeadingZeroes() {
        while amountDigits.count > 1 && amountDigits.first == "0" {
            amountDigits.removeFirst()
        }
    }

    private func accept(rule: ImportRule) {
        if let ruleCategoryId = rule.categoryId {
            categoryId = ruleCategoryId
        }
        if let ruleAccountId = rule.accountId {
            accountId = ruleAccountId
        }
        isReviewed = categoryId != nil
    }

    private func ruleSummary(_ rule: ImportRule) -> String {
        var parts: [String] = [rule.name]
        if let category = categories.category(id: rule.categoryId) {
            parts.append(category.name)
        }
        if let account = accounts.account(id: rule.accountId) {
            parts.append(account.name)
        }
        return parts.joined(separator: " - ")
    }

    @MainActor
    private func readReceipt(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        receiptStatus = "Reading receipt..."
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let cgImage = image.cgImage
            else {
                receiptStatus = "Could not read image"
                return
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            applyReceiptText(text)
        } catch {
            receiptStatus = "Receipt read failed"
        }
    }

    private func applyReceiptText(_ text: String) {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cleanMerchant.isEmpty, let candidate = lines.first(where: { $0.rangeOfCharacter(from: .letters) != nil }) {
            merchant = String(candidate.prefix(42))
        }

        if let receiptDate = Self.firstDate(in: lines) {
            date = receiptDate
        }

        if let amount = Self.largestAmount(in: text) {
            amountDigits = Self.digits(from: amount)
            receiptStatus = "Receipt scanned"
        } else {
            receiptStatus = "Receipt scanned, amount missing"
        }
    }

    private func save() {
        if let transaction {
            transaction.date = date
            transaction.merchant = cleanMerchant
            transaction.narration = narration
            transaction.amount = amountValue.absoluteValue
            transaction.type = type
            transaction.categoryId = categoryId
            transaction.accountId = accountId
            transaction.projectId = projectId
            transaction.note = note
            transaction.isReviewed = isReviewed
            transaction.refreshFingerprint()
        } else {
            let transaction = BudgetTransaction(
                date: date,
                merchant: cleanMerchant,
                narration: narration,
                amount: amountValue,
                type: type,
                categoryId: categoryId,
                accountId: accountId,
                projectId: projectId,
                source: .manual,
                note: note,
                isReviewed: isReviewed
            )
            modelContext.insert(transaction)
        }
        try? modelContext.save()
        dismiss()
    }

    private static func digits(from amount: Decimal) -> String {
        var cents = amount.roundedToPaise * Decimal(100)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .plain)
        let value = NSDecimalNumber(decimal: rounded).int64Value
        return value > 0 ? String(value) : ""
    }

    private static func largestAmount(in text: String) -> Decimal? {
        let pattern = #"(?<!\d)(?:₹|INR|Rs\.?\s*)?([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{2})|[0-9]+(?:\.[0-9]{2}))(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range)
            .compactMap { match -> Decimal? in
                guard let amountRange = Range(match.range(at: 1), in: text) else { return nil }
                let cleaned = text[amountRange].replacingOccurrences(of: ",", with: "")
                return Decimal(string: cleaned)
            }
            .max()
    }

    private static func firstDate(in lines: [String]) -> Date? {
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "d MMM yyyy", "dd MMM yyyy", "MMM d, yyyy"]
        for line in lines {
            for format in formats {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = format
                if let date = formatter.date(from: line) {
                    return date
                }
            }
        }
        return nil
    }
}
