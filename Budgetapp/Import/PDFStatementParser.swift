import Foundation

/// Parses the *text* of a bank/card statement into `ParsedTransaction` rows.
///
/// Extraction from the PDF file itself lives in `PDFTextExtractor` (PDFKit);
/// this type works purely on `String` input so the heuristics can be unit
/// tested against statement fixtures without any PDF binaries.
///
/// Heuristic, line oriented:
///  1. A transaction line starts with a recognisable date.
///  2. Monetary tokens (numbers with 2 decimals, optional `CR`/`DR`) are pulled
///     from the end of the line. The last is treated as a running balance when
///     two or more are present; the one before it is the transaction amount.
///  3. Direction (income vs expense) is inferred from an explicit `CR`/`DR`
///     marker, or — failing that — from the change in running balance between
///     consecutive rows. Rows that remain ambiguous are flagged `needsReview`.
enum PDFStatementParser {

    static func parse(text: String) -> [ParsedTransaction] {
        let lines = text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var results: [ParsedTransaction] = []
        var previousBalance: Decimal?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard let dateMatch = leadingDate(in: line) else { continue }

            // Tokenize only the text after the date so digits inside a
            // dot-separated date can't be mistaken for amounts.
            let afterDate = String(line[dateMatch.range.upperBound...])
            let tokens = monetaryTokens(in: afterDate)
            guard !tokens.isEmpty else { continue }

            // Description is the text between the date and the first money token.
            let description = descriptionPortion(afterDate, firstTokenText: tokens.first?.text)

            // Layout: [... amount, balance] when 2+ tokens, else [amount].
            let amountToken: MoneyToken
            var balance: Decimal?
            if tokens.count >= 2 {
                amountToken = tokens[tokens.count - 2]
                balance = tokens[tokens.count - 1].value
            } else {
                amountToken = tokens[0]
            }

            var type: TransactionType = .expense
            var needsReview = false
            var issues: [String] = []

            if let marker = amountToken.marker {
                type = (marker == .credit) ? .income : .expense
            } else if let balance, let previous = previousBalance {
                type = (balance >= previous) ? .income : .expense
            } else {
                // No marker and no prior balance to compare against.
                needsReview = true
                issues.append("Direction (debit/credit) uncertain")
            }

            if let balance { previousBalance = balance }

            var txn = ParsedTransaction(
                date: dateMatch.date,
                merchant: description,
                narration: description,
                amount: magnitude(amountToken.value),
                type: type,
                runningBalance: balance,
                needsReview: needsReview,
                issues: issues
            )
            if dateMatch.date == nil { txn.issues.append("Unrecognised date") }
            results.append(txn)
        }

        return results
    }

    // MARK: Date detection

    struct DateMatch {
        let date: Date?
        let range: Range<String.Index>
    }

    private static let dateRegex: NSRegularExpression = {
        // dd/mm/yyyy, dd-mm-yy, yyyy-mm-dd, dd Mon yyyy, dd-Mon-yyyy …
        let pattern = #"^\s*(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}|\d{1,2}[ \-][A-Za-z]{3}[ \-]\d{2,4})"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    private static func leadingDate(in line: String) -> DateMatch? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = dateRegex.firstMatch(in: line, range: full),
              let swiftRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let dateString = String(line[swiftRange])
        return DateMatch(date: ValueParsing.parseDate(dateString), range: swiftRange)
    }

    // MARK: Money detection

    enum CreditDebitMarker { case credit, debit }

    struct MoneyToken {
        let value: Decimal
        let marker: CreditDebitMarker?
        let text: String
    }

    private static let moneyRegex: NSRegularExpression = {
        // Optional currency sign, grouped integer part, exactly 2 decimals,
        // optional trailing CR/DR. Requiring decimals avoids matching ref numbers.
        let pattern = #"[₹$€£]?\(?-?\d{1,3}(?:[,]\d{2,3})*(?:\.\d{2})\)?\s?(?:CR|DR|Cr|Dr|cr|dr)?"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    static func monetaryTokens(in line: String) -> [MoneyToken] {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = moneyRegex.matches(in: line, range: full)
        return matches.compactMap { match in
            let text = ns.substring(with: match.range)
            guard let value = ValueParsing.parseAmount(text) else { return nil }
            let upper = text.uppercased()
            var marker: CreditDebitMarker?
            if upper.contains("CR") { marker = .credit }
            else if upper.contains("DR") { marker = .debit }
            return MoneyToken(value: value, marker: marker, text: text)
        }
    }

    // MARK: Helpers

    private static func descriptionPortion(_ afterDate: String, firstTokenText: String?) -> String {
        var text = afterDate
        if let token = firstTokenText, let range = text.range(of: token) {
            text = String(text[text.startIndex..<range.lowerBound])
        }
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }

    private static func magnitude(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}
