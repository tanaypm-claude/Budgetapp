import Foundation
import SwiftData

@Model
final class RecurringPayment {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var categoryId: UUID?
    var accountId: UUID?
    var frequencyRaw: String
    var nextExpectedDate: Date
    var isActive: Bool
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal = 0,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        frequency: RecurringFrequency = .monthly,
        nextExpectedDate: Date = .now,
        isActive: Bool = true,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.categoryId = categoryId
        self.accountId = accountId
        self.frequencyRaw = frequency.rawValue
        self.nextExpectedDate = nextExpectedDate
        self.isActive = isActive
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() { updatedAt = .now }

    /// Roll `nextExpectedDate` forward until it is in the future.
    func advanceToFuture(now: Date = .now, calendar: Calendar = .current) {
        var next = nextExpectedDate
        var guardCount = 0
        while next <= now && guardCount < 1000 {
            next = frequency.nextDate(after: next, calendar: calendar)
            guardCount += 1
        }
        nextExpectedDate = next
    }
}
