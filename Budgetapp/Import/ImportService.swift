import Foundation
import SwiftData

/// Orchestrates the end-to-end import pipeline:
/// file → parse → map → rules → dedupe → preview → commit.
/// The heavy lifting lives in the pure parsers/engines; this service does the
/// SwiftData lookups and persistence around them.
@MainActor
struct ImportService {

    let context: ModelContext

    // MARK: CSV

    struct CSVSession {
        var table: CSVTable
        var mapping: ColumnMapping
        var filename: String
    }

    /// Read a CSV file and auto-detect its delimiter + column mapping.
    func loadCSV(url: URL) throws -> CSVSession {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadableFile
        }
        let delimiter = CSVParser.detectDelimiter(text)
        let table = try CSVParser.parse(text, delimiter: delimiter)
        let mapping = ColumnMapping.autoDetect(headers: table.headers)
        return CSVSession(table: table, mapping: mapping, filename: url.lastPathComponent)
    }

    /// Build a preview from a confirmed CSV mapping.
    func makeCSVPreview(table: CSVTable, mapping: ColumnMapping, filename: String) throws -> ImportPreview {
        let parsed = CSVTransactionMapper.map(table: table, mapping: mapping)
        guard !parsed.isEmpty else { throw ImportError.noTransactionsFound }
        let resolved = resolve(parsed)
        var warnings: [String] = []
        if !mapping.isValid, let message = mapping.validationMessage { warnings.append(message) }
        return ImportPreview(fileType: .csv, filename: filename, transactions: resolved, warnings: warnings, fatalMessage: nil)
    }

    // MARK: PDF

    func loadPDF(url: URL) throws -> ImportPreview {
        let extraction = try PDFTextExtractor.extract(from: url)
        if extraction.looksScanned {
            return ImportPreview(
                fileType: .pdf,
                filename: url.lastPathComponent,
                transactions: [],
                warnings: [],
                fatalMessage: ImportError.scannedPDF.localizedDescription
            )
        }
        let parsed = PDFStatementParser.parse(text: extraction.text)
        guard !parsed.isEmpty else {
            return ImportPreview(
                fileType: .pdf,
                filename: url.lastPathComponent,
                transactions: [],
                warnings: [],
                fatalMessage: ImportError.noTransactionsFound.localizedDescription
            )
        }
        let resolved = resolve(parsed)
        let warnings = ["Extracted from text-based PDF — please verify the rows below before saving."]
        return ImportPreview(fileType: .pdf, filename: url.lastPathComponent, transactions: resolved, warnings: warnings, fatalMessage: nil)
    }

    // MARK: Resolution (rules + names + dedupe)

    /// Resolve category/account from CSV-provided names and import rules, then
    /// flag duplicates and mark uncertain rows for review.
    func resolve(_ parsed: [ParsedTransaction]) -> [ParsedTransaction] {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let rules = ((try? context.fetch(FetchDescriptor<ImportRule>())) ?? []).map(\.spec)
        let existing = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let signatures = DeduplicationService.signatures(for: existing)

        let categoryByName = Dictionary(categories.map { ($0.name.lowercased(), $0.id) }, uniquingKeysWith: { a, _ in a })
        let accountByName = Dictionary(accounts.map { ($0.name.lowercased(), $0.id) }, uniquingKeysWith: { a, _ in a })

        var resolved = parsed.map { row -> ParsedTransaction in
            var row = row

            // 1. Names provided directly by the file.
            if let name = row.categoryName?.lowercased(), let id = categoryByName[name] {
                row.resolvedCategoryId = id
            }
            if let name = row.accountName?.lowercased(), let id = accountByName[name] {
                row.resolvedAccountId = id
            }

            // 2. Rules (only fill what's still missing).
            let input = RuleInput(
                merchant: row.merchant,
                description: row.narration,
                amount: row.amount,
                accountName: row.accountName ?? ""
            )
            let outcome = RulesEngine.firstMatch(rules: rules, input: input)
            if row.resolvedCategoryId == nil { row.resolvedCategoryId = outcome.categoryId }
            if row.resolvedAccountId == nil { row.resolvedAccountId = outcome.accountId }
            row.matchedRuleId = outcome.matchedRuleId

            // 3. Uncertain rows (no category) go to review.
            if row.resolvedCategoryId == nil {
                row.needsReview = true
                if !row.issues.contains("No category — needs review") {
                    row.issues.append("No category — needs review")
                }
            }
            return row
        }

        resolved = DeduplicationService.flagDuplicates(in: resolved, existing: signatures)
        return resolved
    }

    // MARK: Commit

    @discardableResult
    func commit(preview: ImportPreview, defaultAccountId: UUID?) throws -> ImportBatch {
        let rows = preview.transactions.filter { $0.isSelectedForImport && !$0.isDuplicate }
        let batch = ImportBatch(
            filename: preview.filename,
            fileType: preview.fileType,
            rowCount: rows.count,
            status: rows.isEmpty ? .partial : .completed,
            duplicateCount: preview.transactions.filter(\.isDuplicate).count,
            needsReviewCount: rows.filter(\.needsReview).count
        )
        context.insert(batch)

        let source: TransactionSource = preview.fileType == .csv ? .csvImport : .pdfImport
        for row in rows {
            let transaction = Transaction(
                date: row.date ?? .now,
                merchant: row.merchant,
                narration: row.narration,
                amount: row.amount,
                type: row.type,
                categoryId: row.resolvedCategoryId,
                accountId: row.resolvedAccountId ?? defaultAccountId,
                source: source,
                importId: batch.id,
                isReviewed: !row.needsReview
            )
            context.insert(transaction)
        }
        try context.save()
        return batch
    }
}
