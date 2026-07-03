import Foundation

struct DraftTransaction: Identifiable, Codable, RuleMatchable {
    var id: UUID
    var date: Date
    var merchant: String
    var narration: String
    var amount: Decimal
    var type: TransactionType
    var categoryId: UUID?
    var accountId: UUID?
    var projectId: UUID?
    var source: TransactionSource
    var importId: UUID?
    var note: String
    var isReviewed: Bool
    var confidence: Double
    var rawValues: [String: String]
    var duplicateCandidate: Bool
    var appliedRuleId: UUID?

    init(
        id: UUID = UUID(),
        date: Date,
        merchant: String,
        narration: String = "",
        amount: Decimal,
        type: TransactionType,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        projectId: UUID? = nil,
        source: TransactionSource,
        importId: UUID? = nil,
        note: String = "",
        isReviewed: Bool = false,
        confidence: Double = 0.75,
        rawValues: [String: String] = [:],
        duplicateCandidate: Bool = false,
        appliedRuleId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        self.narration = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amount = amount.absoluteValue
        self.type = type
        self.categoryId = categoryId
        self.accountId = accountId
        self.projectId = projectId
        self.source = source
        self.importId = importId
        self.note = note
        self.isReviewed = isReviewed
        self.confidence = confidence
        self.rawValues = rawValues
        self.duplicateCandidate = duplicateCandidate
        self.appliedRuleId = appliedRuleId
    }

    var ruleMerchant: String { merchant }
    var ruleDescription: String { narration }
    var ruleAmount: Decimal { amount }
    var ruleAccountName: String? { rawValues["account"] }

    var needsReviewReason: String? {
        if duplicateCandidate { return "Possible duplicate" }
        if categoryId == nil { return "Category needed" }
        if confidence < 0.7 { return "Low confidence" }
        return nil
    }
}
