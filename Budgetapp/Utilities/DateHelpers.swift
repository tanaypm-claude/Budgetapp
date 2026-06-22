import Foundation

extension Date {
    /// "12 Jun 2026"
    var mediumDay: String {
        Date.mediumDayFormatter.string(from: self)
    }

    /// "Jun 12" — compact, year omitted.
    var shortDay: String {
        Date.shortDayFormatter.string(from: self)
    }

    /// "June 2026"
    var monthYear: String {
        Date.monthYearFormatter.string(from: self)
    }

    /// Relative phrase like "Today", "Yesterday", else the medium day.
    var friendlyDay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        return mediumDay
    }

    func startOfMonth(calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }

    func addingMonths(_ months: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: months, to: self) ?? self
    }

    private static let mediumDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }()
    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
}
