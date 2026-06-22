import Foundation

/// A transaction extracted from a file *before* it becomes a persisted
/// `Transaction`. Pure value type so the whole import pipeline (parse → map →
/// rules → dedupe) can be unit tested without a SwiftData store.
struct ParsedTransaction: Identifiable, Hashable {
    let id: UUID
    var date: Date?
    var merchant: String
    var narration: String
    /// Positive magnitude of the money moved.
    var amount: Decimal
    var type: TransactionType
    var accountName: String?
    var categoryName: String?
    /// Original balance column value if the statement provided one (informational).
    var runningBalance: Decimal?

    /// Resolved during the import flow.
    var resolvedCategoryId: UUID?
    var resolvedAccountId: UUID?
    var matchedRuleId: UUID?

    /// Set when the row is ambiguous and should land in the review queue.
    var needsReview: Bool
    /// Human-readable reason shown in the preview.
    var issues: [String]
    var isDuplicate: Bool
    /// User toggle in the preview screen — excluded rows are not saved.
    var isSelectedForImport: Bool

    init(
        id: UUID = UUID(),
        date: Date? = nil,
        merchant: String = "",
        narration: String = "",
        amount: Decimal = 0,
        type: TransactionType = .expense,
        accountName: String? = nil,
        categoryName: String? = nil,
        runningBalance: Decimal? = nil,
        resolvedCategoryId: UUID? = nil,
        resolvedAccountId: UUID? = nil,
        matchedRuleId: UUID? = nil,
        needsReview: Bool = false,
        issues: [String] = [],
        isDuplicate: Bool = false,
        isSelectedForImport: Bool = true
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.narration = narration
        self.amount = amount
        self.type = type
        self.accountName = accountName
        self.categoryName = categoryName
        self.runningBalance = runningBalance
        self.resolvedCategoryId = resolvedCategoryId
        self.resolvedAccountId = resolvedAccountId
        self.matchedRuleId = matchedRuleId
        self.needsReview = needsReview
        self.issues = issues
        self.isDuplicate = isDuplicate
        self.isSelectedForImport = isSelectedForImport
    }

    /// A display label for the merchant column, falling back to narration.
    var displayName: String {
        if !merchant.trimmingCharacters(in: .whitespaces).isEmpty { return merchant }
        if !narration.trimmingCharacters(in: .whitespaces).isEmpty { return narration }
        return "Unknown"
    }
}

/// Tabular CSV data: an ordered list of header names plus rows of cell strings.
struct CSVTable: Equatable {
    var headers: [String]
    var rows: [[String]]

    var isEmpty: Bool { rows.isEmpty }

    /// Row as a `[header: value]` dictionary, tolerating ragged rows.
    func dictionary(for row: [String]) -> [String: String] {
        var dict: [String: String] = [:]
        for (index, header) in headers.enumerated() {
            dict[header] = index < row.count ? row[index] : ""
        }
        return dict
    }
}

/// The outcome of running a file through the parser + mapper, ready to drive
/// the preview/mapping screen.
struct ImportPreview {
    var fileType: ImportFileType
    var filename: String
    var transactions: [ParsedTransaction]
    var warnings: [String]
    /// Set when nothing usable could be extracted (e.g. scanned PDF).
    var fatalMessage: String?

    var importableCount: Int {
        transactions.filter { $0.isSelectedForImport && !$0.isDuplicate }.count
    }
}

enum ImportError: LocalizedError, Equatable {
    case emptyFile
    case unreadableFile
    case noColumnsDetected
    case scannedPDF
    case noTransactionsFound
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The file appears to be empty."
        case .unreadableFile:
            return "The file could not be read as text."
        case .noColumnsDetected:
            return "No columns could be detected in this CSV."
        case .scannedPDF:
            return "This looks like a scanned or image-only PDF. Text extraction "
                + "isn't possible and OCR is not implemented in this version."
        case .noTransactionsFound:
            return "No transaction rows could be recognised in this file."
        case .custom(let message):
            return message
        }
    }
}
