import Foundation
import SwiftData

enum ImportPipeline {
    static func preparedDrafts(
        _ drafts: [DraftTransaction],
        rules: [ImportRule],
        existingTransactions: [BudgetTransaction]
    ) -> [DraftTransaction] {
        let ruled = drafts.map { draft in
            var copy = draft
            RulesEngine.apply(to: &copy, rules: rules)
            copy.isReviewed = copy.categoryId != nil && copy.confidence >= 0.7
            return copy
        }
        return DedupingService.markDuplicates(ruled, existing: existingTransactions)
    }

    @discardableResult
    static func save(
        drafts: [DraftTransaction],
        filename: String,
        fileType: ImportFileType,
        modelContext: ModelContext,
        skipDuplicates: Bool = true
    ) throws -> ImportBatch {
        let rowsToSave = skipDuplicates ? drafts.filter { !$0.duplicateCandidate } : drafts
        let batch = ImportBatch(
            filename: filename,
            fileType: fileType,
            rowCount: rowsToSave.count,
            status: rowsToSave.count == drafts.count ? .completed : .partial,
            message: rowsToSave.count == drafts.count ? "" : "\(drafts.count - rowsToSave.count) duplicate row(s) skipped."
        )
        modelContext.insert(batch)

        for draft in rowsToSave {
            let transaction = BudgetTransaction(
                date: draft.date,
                merchant: draft.merchant,
                narration: draft.narration,
                amount: draft.amount,
                type: draft.type,
                categoryId: draft.categoryId,
                accountId: draft.accountId,
                projectId: draft.projectId,
                source: draft.source,
                importId: batch.id,
                note: draft.note,
                isReviewed: draft.isReviewed && draft.categoryId != nil && draft.confidence >= 0.7
            )
            modelContext.insert(transaction)
        }

        try modelContext.save()
        return batch
    }
}
