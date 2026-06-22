import XCTest
@testable import Budgetapp

final class ValueParsingTests: XCTestCase {

    func testParsesPlainAmount() {
        XCTAssertEqual(ValueParsing.parseAmount("1234.56"), Decimal(string: "1234.56"))
    }

    func testParsesIndianGrouping() {
        XCTAssertEqual(ValueParsing.parseAmount("1,23,456.78"), Decimal(string: "123456.78"))
    }

    func testParsesUSGrouping() {
        XCTAssertEqual(ValueParsing.parseAmount("1,234.50"), Decimal(string: "1234.50"))
    }

    func testParsesEuropeanDecimal() {
        XCTAssertEqual(ValueParsing.parseAmount("1.234,56"), Decimal(string: "1234.56"))
    }

    func testParsesCurrencySymbol() {
        XCTAssertEqual(ValueParsing.parseAmount("₹450.00"), Decimal(string: "450.00"))
        XCTAssertEqual(ValueParsing.parseAmount("$1,000.00"), Decimal(string: "1000.00"))
    }

    func testParensMeanNegative() {
        XCTAssertEqual(ValueParsing.parseAmount("(1,200.00)"), Decimal(string: "-1200.00"))
    }

    func testCreditDebitMarkers() {
        XCTAssertEqual(ValueParsing.parseAmount("500.00 CR"), Decimal(string: "500.00"))
        XCTAssertEqual(ValueParsing.parseAmount("500.00 DR"), Decimal(string: "-500.00"))
    }

    func testEmptyAndGarbageReturnNil() {
        XCTAssertNil(ValueParsing.parseAmount(""))
        XCTAssertNil(ValueParsing.parseAmount("   "))
        XCTAssertNil(ValueParsing.parseAmount("abc"))
    }

    func testParsesCommonDateFormats() {
        let formats = ["2026-06-22", "22/06/2026", "22-06-2026", "22 Jun 2026", "22-Jun-2026"]
        for input in formats {
            XCTAssertNotNil(ValueParsing.parseDate(input), "Expected to parse \(input)")
        }
    }

    func testRejectsUnparseableDate() {
        XCTAssertNil(ValueParsing.parseDate("not a date"))
        XCTAssertNil(ValueParsing.parseDate(""))
    }

    func testDateComponentsAreCorrect() {
        let date = ValueParsing.parseDate("2026-06-22")
        let comps = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 22)
    }
}
