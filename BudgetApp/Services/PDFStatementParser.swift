import Foundation
import PDFKit

struct ParsedPDFRow: Identifiable {
    var id = UUID()
    var date: Date
    var description: String
    var debit: Decimal?
    var credit: Decimal?
    var balance: Decimal?
    var confidence: Double
    var rawLine: String

    var amount: Decimal {
        (debit ?? credit ?? 0).absoluteValue
    }

    var type: TransactionType {
        credit != nil ? .income : .expense
    }
}

struct PDFParseResult {
    var rows: [ParsedPDFRow]
    var warnings: [String]
    var textCharacterCount: Int
}

enum PDFStatementError: LocalizedError {
    case unreadablePDF
    case scannedPDF
    case noTransactionsFound
    case tooManyPages(pageCount: Int, maxPages: Int)

    var errorDescription: String? {
        switch self {
        case .unreadablePDF:
            return "This PDF could not be opened."
        case .scannedPDF:
            return "This looks like a scanned or image-only PDF. Text extraction produced too little readable text, and OCR is not implemented yet."
        case .noTransactionsFound:
            return "The PDF contained text, but no transaction-like rows were found. You can try a CSV export from the bank instead."
        case let .tooManyPages(pageCount, maxPages):
            return "This PDF has \(pageCount) pages. Import statements with \(maxPages) pages or fewer to keep the app responsive."
        }
    }
}

enum PDFStatementParser {
    static let maxPageCount = 50

    static func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw PDFStatementError.unreadablePDF
        }
        guard document.pageCount <= maxPageCount else {
            throw PDFStatementError.tooManyPages(pageCount: document.pageCount, maxPages: maxPageCount)
        }

        var text = ""
        for index in 0..<document.pageCount {
            if let pageText = document.page(at: index)?.string {
                text += pageText
                text += "\n"
            }
        }

        let readableCharacterCount = text.filter { $0.isLetter || $0.isNumber }.count
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || readableCharacterCount < 30 {
            throw PDFStatementError.scannedPDF
        }
        return text
    }

    static func parse(text: String) throws -> PDFParseResult {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var rows: [ParsedPDFRow] = []
        var previousBalance: Decimal?
        for line in lines {
            guard let row = parseLine(line, previousBalance: previousBalance) else { continue }
            rows.append(row)
            if let balance = row.balance {
                previousBalance = balance
            }
        }
        if rows.isEmpty {
            throw PDFStatementError.noTransactionsFound
        }

        let warnings = rows.filter { $0.confidence < 0.7 }.isEmpty ? [] : [
            "Some rows were parsed with low confidence. Review them before saving."
        ]
        return PDFParseResult(rows: rows, warnings: warnings, textCharacterCount: text.count)
    }

    static func drafts(from result: PDFParseResult, defaultAccountId: UUID?) -> [DraftTransaction] {
        result.rows.map { row in
            DraftTransaction(
                date: row.date,
                merchant: row.description,
                narration: row.rawLine,
                amount: row.amount,
                type: row.type,
                accountId: defaultAccountId,
                source: .pdfImport,
                isReviewed: false,
                confidence: row.confidence,
                rawValues: [
                    "description": row.description,
                    "rawLine": row.rawLine,
                    "balance": row.balance.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
                ]
            )
        }
    }

    private static func parseLine(_ line: String, previousBalance: Decimal? = nil) -> ParsedPDFRow? {
        guard let dateMatch = firstDate(in: line) else { return nil }
        let afterDate = String(line[dateMatch.range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let amountMatches = amountTokens(in: afterDate)
        guard !amountMatches.isEmpty else { return nil }

        let descriptionEnd = amountMatches.first?.range.lowerBound ?? afterDate.endIndex
        let description = String(afterDate[..<descriptionEnd])
            .replacingOccurrences(of: #"[\s]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return nil }

        let tokens = amountMatches.map(\.value)
        let upperLine = line.uppercased()
        var debit: Decimal?
        var credit: Decimal?
        var balance: Decimal?
        var confidence = 0.78

        if tokens.count >= 3 {
            let debitCandidate = CSVImportEngine.parseCurrency(tokens[tokens.count - 3])
            let creditCandidate = CSVImportEngine.parseCurrency(tokens[tokens.count - 2])
            balance = CSVImportEngine.parseCurrency(tokens[tokens.count - 1])?.absoluteValue

            if let inferred = directionFromBalance(previous: previousBalance, current: balance) {
                if inferred == .income {
                    credit = (nonZero(creditCandidate) ?? nonZero(debitCandidate))?.absoluteValue
                } else {
                    debit = (nonZero(debitCandidate) ?? nonZero(creditCandidate))?.absoluteValue
                }
                confidence = 0.9
            } else if let creditCandidate, creditCandidate != 0, upperLine.contains("CR") || upperLine.contains("CREDIT") || upperLine.contains("DEPOSIT") {
                credit = creditCandidate.absoluteValue
            } else if let debitCandidate, debitCandidate != 0 {
                debit = debitCandidate.absoluteValue
            } else if let creditCandidate, creditCandidate != 0 {
                credit = creditCandidate.absoluteValue
                confidence = 0.62
            }
        } else {
            let amount = CSVImportEngine.parseCurrency(tokens[0])
            if tokens.count == 2 {
                balance = CSVImportEngine.parseCurrency(tokens[1])?.absoluteValue
            }

            guard let amount else { return nil }
            if let inferred = directionFromBalance(previous: previousBalance, current: balance) {
                if inferred == .income {
                    credit = amount.absoluteValue
                } else {
                    debit = amount.absoluteValue
                }
                confidence = 0.88
            } else if amount < 0 || upperLine.contains("DR") || upperLine.contains("DEBIT") || upperLine.contains("WITHDRAWAL") {
                debit = amount.absoluteValue
            } else if upperLine.contains("CR") || upperLine.contains("CREDIT") || upperLine.contains("DEPOSIT") {
                credit = amount.absoluteValue
            } else {
                debit = amount.absoluteValue
                confidence = 0.58
            }
        }

        guard debit != nil || credit != nil else { return nil }
        if balance == nil && tokens.count > 1 {
            confidence -= 0.08
        }

        return ParsedPDFRow(
            date: dateMatch.date,
            description: description,
            debit: debit,
            credit: credit,
            balance: balance,
            confidence: max(0.35, confidence),
            rawLine: line
        )
    }

    private static func firstDate(in line: String) -> (date: Date, range: Range<String.Index>)? {
        let patterns = [
            #"\b\d{4}-\d{2}-\d{2}\b"#,
            #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,
            #"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}\b"#
        ]

        for pattern in patterns {
            guard let range = line.range(of: pattern, options: .regularExpression) else { continue }
            let value = String(line[range])
            if let date = CSVImportEngine.parseDate(value) {
                return (date, range)
            }
        }
        return nil
    }

    private static func amountTokens(in line: String) -> [(value: String, range: Range<String.Index>)] {
        let pattern = #"(?:\p{Sc}|INR|Rs\.?)?\s*-?\d[\d,]*\.\d{1,2}\s*(?:CR|DR|Cr|Dr)?"#
        var matches: [(String, Range<String.Index>)] = []
        var searchStart = line.startIndex

        while searchStart < line.endIndex,
              let range = line[searchStart...].range(of: pattern, options: .regularExpression) {
            let token = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if CSVImportEngine.parseCurrency(token) != nil {
                matches.append((token, range))
            }
            searchStart = range.upperBound
        }
        return matches
    }

    private static func nonZero(_ value: Decimal?) -> Decimal? {
        guard let value, value != .zero else { return nil }
        return value
    }

    private static func directionFromBalance(previous: Decimal?, current: Decimal?) -> TransactionType? {
        guard let previous, let current else { return nil }
        let delta = current - previous
        if delta > Decimal(0.005) {
            return .income
        }
        if delta < Decimal(-0.005) {
            return .expense
        }
        return nil
    }
}
