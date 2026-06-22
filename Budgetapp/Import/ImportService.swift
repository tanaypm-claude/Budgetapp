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

    /// Build a preview from a confirmed CSV mapping. Throws when the mapping is
    /// incomplete so an under-specified import can never reach preview/commit.
    func makeCSVPreview(table: CSVTable, mapping: ColumnMapping, filename: String) throws -> ImportPreview {
        guard mapping.isValid else {
            throw ImportError.custom(mapping.validationMessage ?? "The column mapping is incomplete.")
        }
        let parsed = CSVTransactionMapper.map(table: table, mapping: mapping)
        guard !parsed.isEmpty else { throw ImportError.noTransactionsFound }
        let resolved = resolve(parsed)
        let warnings = resolved.contains(where: { $0.date == nil })
            ? ["Some rows have an unreadable date — set a date on those rows before they can be saved."]
            : []
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
        // Authoritative dedupe at commit time, using the *final* account each row
        // will be saved with (per-row override, else the default).
        let existing = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        var seen = DeduplicationService.signatures(for: existing)

        var committable: [(row: ParsedTransaction, date: Date, accountId: UUID?)] = []
        var skippedNoDate = 0
        var skippedDuplicate = 0

        for row in preview.transactions where row.isSelectedForImport && !row.isDuplicate {
            // Never let a missing/unparseable date become "today".
            guard let date = row.date else { skippedNoDate += 1; continue }
            let finalAccount = row.resolvedAccountId ?? defaultAccountId
            let signature = TransactionSignature(
                date: date, amount: row.amount, merchant: row.displayName, accountId: finalAccount
            )
            if seen.contains(signature) { skippedDuplicate += 1; continue }
            seen.insert(signature)
            committable.append((row: row, date: date, accountId: finalAccount))
        }

        let total = preview.transactions.count
        var notes: [String] = []
        if skippedNoDate > 0 { notes.append("\(skippedNoDate) skipped for missing date") }
        if skippedDuplicate > 0 { notes.append("\(skippedDuplicate) duplicate(s) skipped") }

        let batch = ImportBatch(
            filename: preview.filename,
            fileType: preview.fileType,
            rowCount: committable.count,
            status: committable.count == total ? .completed : .partial,
            duplicateCount: preview.transactions.filter(\.isDuplicate).count + skippedDuplicate,
            needsReviewCount: committable.filter { $0.row.needsReview }.count,
            note: notes.joined(separator: "; ")
        )
        context.insert(batch)

        let source: TransactionSource = preview.fileType == .csv ? .csvImport : .pdfImport
        for entry in committable {
            let transaction = Transaction(
                date: entry.date,
                merchant: entry.row.merchant,
                narration: entry.row.narration,
                amount: entry.row.amount,
                type: entry.row.type,
                categoryId: entry.row.resolvedCategoryId,
                accountId: entry.accountId,
                source: source,
                importId: batch.id,
                isReviewed: !entry.row.needsReview && entry.row.resolvedCategoryId != nil
            )
            context.insert(transaction)
        }
        try context.save()
        return batch
    }
}
