import Foundation

/// Shared value enums used by both the SwiftData models and the pure-logic
/// services. They are `String`-backed so SwiftData can persist them directly
/// and so import/export (JSON) stays stable and human-readable.

enum TransactionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case income
    case expense
    case transfer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        }
    }

    var symbolName: String {
        switch self {
        case .income: return "arrow.down.circle"
        case .expense: return "arrow.up.circle"
        case .transfer: return "arrow.left.arrow.right.circle"
        }
    }

    /// The sign a transaction of this type applies to an account balance.
    var balanceSign: Decimal {
        switch self {
        case .income: return 1
        case .expense: return -1
        case .transfer: return 0
        }
    }
}

enum TransactionSource: String, Codable, CaseIterable, Identifiable, Hashable {
    case manual
    case csvImport
    case pdfImport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .csvImport: return "CSV Import"
        case .pdfImport: return "PDF Import"
        }
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable, Hashable {
    case bank
    case creditCard
    case cash
    case wallet
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bank: return "Bank"
        case .creditCard: return "Credit Card"
        case .cash: return "Cash"
        case .wallet: return "Wallet"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .bank: return "building.columns"
        case .creditCard: return "creditcard"
        case .cash: return "banknote"
        case .wallet: return "wallet.pass"
        case .other: return "square.stack"
        }
    }
}

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable, Hashable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    /// Advance a date by one period of this frequency.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

enum ImportFileType: String, Codable, CaseIterable, Identifiable, Hashable {
    case csv
    case pdf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .csv: return "CSV"
        case .pdf: return "PDF"
        }
    }
}

enum ImportStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case pending
    case completed
    case failed
    case partial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .partial: return "Partial"
        }
    }
}

enum RuleMatchField: String, Codable, CaseIterable, Identifiable, Hashable {
    case merchant
    case description
    case amount
    case account

    var id: String { rawValue }

    var label: String {
        switch self {
        case .merchant: return "Merchant"
        case .description: return "Description"
        case .amount: return "Amount"
        case .account: return "Account"
        }
    }
}

enum RuleMatchType: String, Codable, CaseIterable, Identifiable, Hashable {
    case contains
    case equals
    case startsWith
    case regex

    var id: String { rawValue }

    var label: String {
        switch self {
        case .contains: return "Contains"
        case .equals: return "Equals"
        case .startsWith: return "Starts With"
        case .regex: return "Regex"
        }
    }
}
