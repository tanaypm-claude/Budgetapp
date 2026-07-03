import SwiftData
import SwiftUI

struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \BudgetAccount.name) private var accounts: [BudgetAccount]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \ImportRule.priority) private var rules: [ImportRule]

    let filename: String
    let fileType: ImportFileType
    let warnings: [String]

    @State private var drafts: [DraftTransaction]
    @State private var skipDuplicates = true
    @State private var teachRules = true
    @State private var errorMessage: String?

    init(state: ImportPreviewState) {
        filename = state.filename
        fileType = state.fileType
        warnings = state.warnings
        _drafts = State(initialValue: state.drafts)
    }

    private var duplicateCount: Int {
        drafts.filter(\.duplicateCandidate).count
    }

    private var reviewCount: Int {
        drafts.filter { !$0.isReviewed || $0.needsReviewReason != nil }.count
    }

    var body: some View {
        List {
            Section {
                MetricTile(title: "Rows", value: "\(drafts.count)", footnote: "\(reviewCount) need review", tint: BudgetTheme.teal)
                Toggle("Teach smart rules from reviewed rows", isOn: $teachRules)
                if duplicateCount > 0 {
                    Toggle("Skip \(duplicateCount) possible duplicate(s)", isOn: $skipDuplicates)
                }
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(BudgetTheme.yellow)
                }
            } header: {
                Text(filename)
            }

            Section("Preview") {
                ForEach($drafts) { $draft in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.merchant)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(draft.narration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(MoneyFormatter.string(draft.amount))
                                    .font(.headline.monospacedDigit())
                                    .privacySensitive()
                                Text(AppDateFormatters.short.string(from: draft.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Picker("Type", selection: $draft.type) {
                            ForEach(TransactionType.allCases) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Category", selection: $draft.categoryId) {
                            Text("Needs review").tag(UUID?.none)
                            ForEach(categories.filter(\.isActive)) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }

                        Picker("Account", selection: $draft.accountId) {
                            Text("No account").tag(UUID?.none)
                            ForEach(accounts.filter(\.isActive)) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }

                        Picker("Project", selection: $draft.projectId) {
                            Text("No project").tag(UUID?.none)
                            ForEach(projects.filter(\.isActive)) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }

                        if let reason = draft.needsReviewReason {
                            Label(reason, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(draft.duplicateCandidate ? BudgetTheme.yellow : .secondary)
                        } else if let ruleId = draft.appliedRuleId {
                            Label("Rule applied: \(ruleId.uuidString.prefix(6))", systemImage: "wand.and.stars")
                                .font(.caption)
                                .foregroundStyle(BudgetTheme.teal)
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(importPreviewAccessibilityLabel(draft))
                    .onChange(of: draft.categoryId) { _, newValue in
                        $draft.isReviewed.wrappedValue = newValue != nil && !draft.duplicateCandidate && draft.confidence >= 0.7
                    }
                }
            }
        }
        .tactileListBackground()
        .navigationTitle("Review Import")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(drafts.isEmpty)
            }
        }
        .alert("Could Not Save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        do {
            var finalDrafts = drafts
            for index in finalDrafts.indices {
                finalDrafts[index].isReviewed = finalDrafts[index].categoryId != nil && !finalDrafts[index].duplicateCandidate && finalDrafts[index].confidence >= 0.7
                if teachRules, finalDrafts[index].isReviewed {
                    learnRule(from: finalDrafts[index])
                }
            }
            try ImportPipeline.save(
                drafts: finalDrafts,
                filename: filename,
                fileType: fileType,
                modelContext: modelContext,
                skipDuplicates: skipDuplicates
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importPreviewAccessibilityLabel(_ draft: DraftTransaction) -> String {
        let category = categories.category(id: draft.categoryId)?.name ?? "Needs review"
        let account = accounts.account(id: draft.accountId)?.name ?? "No account"
        let project = projectName(id: draft.projectId)
        let reason = draft.needsReviewReason.map { ", \($0)" } ?? ""
        return "\(draft.type.label), \(draft.merchant), \(MoneyFormatter.string(draft.amount)), \(category), \(account), \(project), \(AppDateFormatters.short.string(from: draft.date))\(reason)"
    }

    private func learnRule(from draft: DraftTransaction) {
        guard let categoryId = draft.categoryId else { return }
        let seed = ruleSeed(for: draft.merchant)
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
            name: "\(seed) auto-rule",
            matchField: .merchant,
            matchType: .contains,
            matchValue: seed,
            categoryId: categoryId,
            accountId: draft.accountId,
            priority: nextPriority,
            isActive: true
        ))
    }

    private func ruleSeed(for merchant: String) -> String {
        let cleaned = merchant
            .replacingOccurrences(of: #"[^A-Za-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.split(separator: " ").prefix(3).joined(separator: " ")
    }

    private func projectName(id: UUID?) -> String {
        guard let id, let project = projects.first(where: { $0.id == id }) else {
            return "No project"
        }
        return project.name
    }
}
