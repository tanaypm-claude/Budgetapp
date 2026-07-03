import Foundation

struct CSVDocument: Identifiable {
    var id = UUID()
    var headers: [String]
    var rows: [[String]]
    var detectedMapping: CSVColumnMapping
}

struct CSVColumnMapping: Codable, Hashable {
    var date: String? = nil
    var merchant: String? = nil
    var narration: String? = nil
    var debit: String? = nil
    var credit: String? = nil
    var amount: String? = nil
    var account: String? = nil
    var category: String? = nil

    static let empty = CSVColumnMapping()

    var requiredFieldsMapped: Bool {
        date != nil && (merchant != nil || narration != nil) && (amount != nil || debit != nil || credit != nil)
    }
}

struct CSVImportDraftResult {
    var drafts: [DraftTransaction]
    var warnings: [String]
}

enum CSVImportError: LocalizedError {
    case emptyFile
    case missingRequiredMapping
    case unreadableDate(row: Int, value: String)
    case unreadableAmount(row: Int)
    case noUsableRows(warnings: [String])

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file is empty."
        case .missingRequiredMapping:
            return "Map a date, description or merchant, and an amount/debit/credit column."
        case let .unreadableDate(row, value):
            return "Row \(row) has a date that could not be read: \(value)"
        case let .unreadableAmount(row):
            return "Row \(row) does not contain a readable amount."
        case let .noUsableRows(warnings):
            if let firstWarning = warnings.first {
                return "No usable transaction rows were found. \(firstWarning)"
            }
            return "No usable transaction rows were found."
        }
    }
}

enum CSVImportEngine {
    static func parse(data: Data) throws -> CSVDocument {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CSVImportError.emptyFile
        }
        return try parse(text: text)
    }

    static func parse(text: String) throws -> CSVDocument {
        let rows = parseRows(text)
            .filter { row in row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

        guard let headers = rows.first, !headers.isEmpty else {
            throw CSVImportError.emptyFile
        }

        let body = Array(rows.dropFirst())
        let mapping = detectMapping(headers: headers)
        return CSVDocument(headers: headers, rows: body, detectedMapping: mapping)
    }

    static func drafts(
        from document: CSVDocument,
        mapping: CSVColumnMapping,
        defaultAccountId: UUID?,
        categoryLookup: [String: UUID],
        accountLookup: [String: UUID] = [:]
    ) throws -> [DraftTransaction] {
        try draftResult(
            from: document,
            mapping: mapping,
            defaultAccountId: defaultAccountId,
            categoryLookup: categoryLookup,
            accountLookup: accountLookup
        ).drafts
    }

    static func draftResult(
        from document: CSVDocument,
        mapping: CSVColumnMapping,
        defaultAccountId: UUID?,
        categoryLookup: [String: UUID],
        accountLookup: [String: UUID] = [:]
    ) throws -> CSVImportDraftResult {
        guard mapping.requiredFieldsMapped else {
            throw CSVImportError.missingRequiredMapping
        }

        var drafts: [DraftTransaction] = []
        var warnings: [String] = []

        for (index, row) in document.rows.enumerated() {
            let values = keyedValues(headers: document.headers, row: row)
            if values.values.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            guard let dateValue = value(for: mapping.date, in: values),
                  let date = parseDate(dateValue) else {
                let rawDate = value(for: mapping.date, in: values) ?? ""
                warnings.append("Row \(index + 2) skipped: unreadable date\(rawDate.isEmpty ? "." : " '\(rawDate)'.")")
                continue
            }

            let merchant = value(for: mapping.merchant, in: values)
            let narration = value(for: mapping.narration, in: values)
            let name = merchant?.nilIfBlank ?? narration?.nilIfBlank ?? "Imported transaction"

            let amountResult = parseAmount(values: values, mapping: mapping)
            guard let amountResult else {
                warnings.append("Row \(index + 2) skipped: unreadable amount.")
                continue
            }

            let categoryName = value(for: mapping.category, in: values)?.normalizedLookupKey
            let categoryId = categoryName.flatMap { categoryLookup[$0] }
            let accountName = value(for: mapping.account, in: values)?.normalizedLookupKey
            let accountId = accountName.flatMap { accountLookup[$0] } ?? defaultAccountId
            var rawValues = values
            if let accountText = value(for: mapping.account, in: values) {
                rawValues["account"] = accountText
            }
            if let categoryText = value(for: mapping.category, in: values) {
                rawValues["category"] = categoryText
            }

            drafts.append(DraftTransaction(
                date: date,
                merchant: name,
                narration: narration ?? merchant ?? "",
                amount: amountResult.amount,
                type: amountResult.type,
                categoryId: categoryId,
                accountId: accountId,
                source: .csvImport,
                isReviewed: categoryId != nil,
                confidence: categoryId == nil ? 0.65 : 0.9,
                rawValues: rawValues
            ))
        }

        guard !drafts.isEmpty else {
            throw CSVImportError.noUsableRows(warnings: warnings)
        }

        return CSVImportDraftResult(drafts: drafts, warnings: warnings)
    }

    static func detectMapping(headers: [String]) -> CSVColumnMapping {
        func match(_ candidates: [String]) -> String? {
            let normalizedCandidates = candidates.map(\.normalizedLookupKey)

            if let exact = headers.first(where: { header in
                let normalized = header.normalizedLookupKey
                let tokens = header.lookupTokens
                return normalizedCandidates.contains(normalized)
                    || normalizedCandidates.contains { tokens.contains($0) }
            }) {
                return exact
            }

            return headers.first { header in
                let normalized = header.normalizedLookupKey
                return normalizedCandidates.contains { candidate in
                    candidate.count > 2 && normalized.contains(candidate)
                }
            }
        }

        return CSVColumnMapping(
            date: match(["date", "transactiondate", "valuedate", "postingdate"]),
            merchant: match(["merchant", "payee", "vendor", "name"]),
            narration: match(["description", "narration", "details", "particulars", "memo", "remarks"]),
            debit: match(["debit", "withdrawal", "withdraw", "dr", "paidout"]),
            credit: match(["credit", "deposit", "cr", "paidin"]),
            amount: match(["amount", "transactionamount"]),
            account: match(["account"]),
            category: match(["category"])
        )
    }

    private static func parseRows(_ text: String) -> [[String]] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let delimiter = detectDelimiter(in: normalized)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var iterator = normalized.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if insideQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        insideQuotes = false
                        if next == delimiter {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else {
                            field.append(next)
                        }
                    }
                } else {
                    insideQuotes.toggle()
                }
            } else if character == delimiter && !insideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n" && !insideQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    }

    private static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let delimiters: [Character] = [",", ";", "\t"]
        return delimiters.max { lhs, rhs in
            firstLine.filter { $0 == lhs }.count < firstLine.filter { $0 == rhs }.count
        } ?? ","
    }

    private static func keyedValues(headers: [String], row: [String]) -> [String: String] {
        var values: [String: String] = [:]
        for (index, header) in headers.enumerated() {
            values[header] = index < row.count ? row[index] : ""
        }
        return values
    }

    private static func value(for header: String?, in values: [String: String]) -> String? {
        guard let header else { return nil }
        return values[header]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseAmount(values: [String: String], mapping: CSVColumnMapping) -> (amount: Decimal, type: TransactionType)? {
        if let debitHeader = mapping.debit,
           let debit = parseCurrency(values[debitHeader]),
           debit != 0 {
            return (debit.absoluteValue, .expense)
        }

        if let creditHeader = mapping.credit,
           let credit = parseCurrency(values[creditHeader]),
           credit != 0 {
            return (credit.absoluteValue, .income)
        }

        if let amountHeader = mapping.amount,
           let rawAmount = parseCurrency(values[amountHeader]) {
            if rawAmount < 0 {
                return (rawAmount.absoluteValue, .expense)
            }
            return (rawAmount.absoluteValue, .income)
        }

        return nil
    }

    static func parseCurrency(_ value: String?) -> Decimal? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "\u{20B9}", with: "")
            .replacingOccurrences(of: "INR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Rs.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Rs", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let isCredit = cleaned.uppercased().contains("CR")
        let isDebit = cleaned.uppercased().contains("DR")
        let number = cleaned
            .replacingOccurrences(of: "CR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "DR", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Decimal(string: number, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        if isDebit { return -parsed.absoluteValue }
        if isCredit { return parsed.absoluteValue }
        return parsed
    }

    static func parseDate(_ value: String) -> Date? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: cleaned) {
            return date
        }

        let formats = [
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy",
            "dd/MM/yy",
            "MM/dd/yy",
            "dd-MM-yyyy",
            "MM-dd-yyyy",
            "dd-MM-yy",
            "MM-dd-yy",
            "dd MMM yyyy",
            "dd MMM yy",
            "MMM dd yyyy",
            "MMM dd, yyyy"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedLookupKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    var lookupTokens: [String] {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
