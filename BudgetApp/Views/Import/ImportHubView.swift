import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CSVMappingState: Identifiable {
    let id = UUID()
    let filename: String
    let document: CSVDocument
}

struct ImportPreviewState: Identifiable {
    let id = UUID()
    let filename: String
    let fileType: ImportFileType
    var drafts: [DraftTransaction]
    var warnings: [String]
}

enum ImportHubError: LocalizedError {
    case unsupportedFileType
    case fileTooLarge(filename: String, maxMegabytes: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Choose a CSV, TXT, TSV, or text-based PDF statement."
        case let .fileTooLarge(filename, maxMegabytes):
            return "\(filename) is too large to import safely. Use a file under \(maxMegabytes) MB."
        }
    }
}

struct ImportHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \ImportRule.priority) private var rules: [ImportRule]
    @Query(sort: \BudgetTransaction.date, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \ImportBatch.importedAt, order: .reverse) private var importBatches: [ImportBatch]

    @State private var showingFileImporter = false
    @State private var csvMappingState: CSVMappingState?
    @State private var previewState: ImportPreviewState?
    @State private var errorMessage: String?

    private static let maxStatementBytes = 15 * 1024 * 1024
    private static let maxStatementMegabytes = 15

    private var reviewItems: [BudgetTransaction] {
        transactions.filter { !$0.isReviewed }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Add Statement", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 10) {
                    MetricTile(title: "Review", value: "\(reviewItems.count)", footnote: "waiting", tint: reviewItems.isEmpty ? BudgetTheme.moss : BudgetTheme.saffron)
                    MetricTile(title: "Rules", value: "\(rules.filter(\.isActive).count)", footnote: "active", tint: BudgetTheme.teal)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Import Desk")
            }

            Section("Sorting Table") {
                if reviewItems.isEmpty {
                    ContentUnavailableView("Nothing To Sort", systemImage: "checkmark.seal", description: Text("Imported rows that need a decision will gather here."))
                        .frame(minHeight: 130)
                } else {
                    ForEach(reviewItems) { transaction in
                        reviewRow(transaction)
                    }
                }
            }

            Section("Smart Rules") {
                NavigationLink {
                    RulesView()
                } label: {
                    Label("Tune \(rules.filter(\.isActive).count) active rule(s)", systemImage: "wand.and.stars")
                }
            }

            Section("Recent Batches") {
                if importBatches.isEmpty {
                    ContentUnavailableView("No Imports Yet", systemImage: "tray")
                } else {
                    ForEach(importBatches.prefix(10)) { batch in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(batch.filename)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Spacer()
                                Text(batch.status.label)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(batch.status == .completed ? BudgetTheme.green : BudgetTheme.yellow)
                            }
                            HStack {
                                Text(batch.fileType.rawValue.uppercased())
                                Text("\(batch.rowCount) row(s)")
                                Text(AppDateFormatters.short.string(from: batch.importedAt))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if !batch.message.isEmpty {
                                Text(batch.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Import")
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .tabSeparatedText, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(item: $csvMappingState) { state in
            NavigationStack {
                CSVColumnMappingView(document: state.document) { mapping in
                    makeCSVPreview(filename: state.filename, document: state.document, mapping: mapping)
                }
            }
        }
        .sheet(item: $previewState) { state in
            NavigationStack {
                ImportPreviewView(state: state)
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let filename = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()
            try validateFileSize(url, filename: filename)
            if fileExtension == "pdf" {
                let text = try PDFStatementParser.extractText(from: url)
                let parsed = try PDFStatementParser.parse(text: text)
                let drafts = PDFStatementParser.drafts(from: parsed, defaultAccountId: accounts.first(where: \.isActive)?.id)
                previewState = ImportPreviewState(
                    filename: filename,
                    fileType: .pdf,
                    drafts: prepare(drafts),
                    warnings: parsed.warnings
                )
            } else if ["csv", "txt", "tsv"].contains(fileExtension) {
                let data = try Data(contentsOf: url)
                let document = try CSVImportEngine.parse(data: data)
                csvMappingState = CSVMappingState(filename: filename, document: document)
            } else {
                throw ImportHubError.unsupportedFileType
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateFileSize(_ url: URL, filename: String) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > Self.maxStatementBytes {
            throw ImportHubError.fileTooLarge(filename: filename, maxMegabytes: Self.maxStatementMegabytes)
        }
    }

    private func makeCSVPreview(filename: String, document: CSVDocument, mapping: CSVColumnMapping) {
        do {
            var categoryLookup: [String: UUID] = [:]
            categories.forEach { category in
                categoryLookup[category.name.budgetLookupKey] = category.id
            }
            var accountLookup: [String: UUID] = [:]
            accounts.forEach { account in
                accountLookup[account.name.budgetLookupKey] = account.id
            }
            let result = try CSVImportEngine.draftResult(
                from: document,
                mapping: mapping,
                defaultAccountId: accounts.first(where: \.isActive)?.id,
                categoryLookup: categoryLookup,
                accountLookup: accountLookup
            )
            csvMappingState = nil
            previewState = ImportPreviewState(
                filename: filename,
                fileType: .csv,
                drafts: prepare(result.drafts),
                warnings: result.warnings
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepare(_ drafts: [DraftTransaction]) -> [DraftTransaction] {
        ImportPipeline.preparedDrafts(drafts, rules: rules, existingTransactions: transactions)
    }

    private func reviewRow(_ transaction: BudgetTransaction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchant)
                        .font(.headline)
                    if !transaction.narration.isEmpty {
                        Text(transaction.narration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(MoneyFormatter.string(transaction.amount))
                        .font(.headline.monospacedDigit())
                        .privacySensitive()
                    Text(AppDateFormatters.short.string(from: transaction.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                CategoryPill(category: categories.category(id: transaction.categoryId))
                Text(accounts.account(id: transaction.accountId)?.name ?? "No account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(projectName(id: transaction.projectId))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                Menu {
                    ForEach(categories.filter(\.isActive)) { category in
                        Button(category.name) {
                            review(transaction, as: category, createRule: true)
                        }
                    }
                } label: {
                    Label("Assign + Teach", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    ForEach(categories.filter(\.isActive)) { category in
                        Button(category.name) {
                            review(transaction, as: category, createRule: false)
                        }
                    }
                } label: {
                    Label("Assign Only", systemImage: "tag")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            HStack {
                projectMenu(for: transaction)

                Button {
                    transaction.isReviewed = true
                    transaction.touch()
                    try? modelContext.save()
                } label: {
                    Label("Accept", systemImage: "checkmark")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Review \(transaction.merchant), \(MoneyFormatter.string(transaction.amount)), \(projectName(id: transaction.projectId)), \(AppDateFormatters.short.string(from: transaction.date))")
    }

    private func projectMenu(for transaction: BudgetTransaction) -> some View {
        Menu {
            Button("No Project") {
                assignProject(nil, to: transaction)
            }
            ForEach(projects.filter(\.isActive)) { project in
                Button(project.name) {
                    assignProject(project.id, to: transaction)
                }
            }
        } label: {
            Label(projectName(id: transaction.projectId), systemImage: "folder")
        }
        .buttonStyle(.bordered)
    }

    private func review(_ transaction: BudgetTransaction, as category: BudgetCategory, createRule: Bool) {
        transaction.categoryId = category.id
        transaction.isReviewed = true
        transaction.touch()

        if createRule {
            learnRule(from: transaction, category: category)
        }

        try? modelContext.save()
    }

    private func assignProject(_ projectId: UUID?, to transaction: BudgetTransaction) {
        transaction.projectId = projectId
        transaction.touch()
        try? modelContext.save()
    }

    private func learnRule(from transaction: BudgetTransaction, category: BudgetCategory) {
        let seed = ruleSeed(for: transaction.merchant)
        guard !seed.isEmpty else { return }
        let normalizedSeed = seed.budgetLookupKey
        let alreadyExists = rules.contains { rule in
            rule.isActive
                && rule.matchField == .merchant
                && rule.matchType == .contains
                && rule.matchValue.budgetLookupKey == normalizedSeed
        }
        guard !alreadyExists else { return }

        let nextPriority = max(10, (rules.map(\.priority).min() ?? 40) - 1)
        modelContext.insert(ImportRule(
            name: "\(seed) to \(category.name)",
            matchField: .merchant,
            matchType: .contains,
            matchValue: seed,
            categoryId: category.id,
            accountId: transaction.accountId,
            priority: nextPriority,
            isActive: true
        ))
    }

    private func ruleSeed(for merchant: String) -> String {
        let cleaned = merchant
            .replacingOccurrences(of: #"[^A-Za-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(separator: " ").prefix(3).joined(separator: " ")
        return words.isEmpty ? cleaned : words
    }

    private func projectName(id: UUID?) -> String {
        guard let id, let project = projects.first(where: { $0.id == id }) else {
            return "No project"
        }
        return project.name
    }
}

extension String {
    var budgetLookupKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }
}
