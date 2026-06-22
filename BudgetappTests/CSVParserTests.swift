import XCTest
@testable import Budgetapp

final class CSVParserTests: XCTestCase {

    func testParsesSimpleTable() throws {
        let csv = "Date,Merchant,Amount\n2026-06-01,Swiggy,450\n2026-06-02,Uber,320"
        let table = try CSVParser.parse(csv)
        XCTAssertEqual(table.headers, ["Date", "Merchant", "Amount"])
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[0], ["2026-06-01", "Swiggy", "450"])
    }

    func testHandlesQuotedFieldsWithCommas() throws {
        let csv = "Date,Description,Amount\n2026-06-01,\"Swiggy, Bangalore\",450"
        let table = try CSVParser.parse(csv)
        XCTAssertEqual(table.rows[0][1], "Swiggy, Bangalore")
    }

    func testHandlesEscapedQuotes() throws {
        let csv = "Name\n\"He said \"\"hi\"\"\""
        let table = try CSVParser.parse(csv)
        XCTAssertEqual(table.rows[0][0], "He said \"hi\"")
    }

    func testHandlesQuotedNewlines() throws {
        let csv = "Note,Amount\n\"line1\nline2\",100"
        let table = try CSVParser.parse(csv)
        XCTAssertEqual(table.rows.count, 1)
        XCTAssertEqual(table.rows[0][0], "line1\nline2")
    }

    func testHandlesCRLF() throws {
        let csv = "A,B\r\n1,2\r\n3,4"
        let table = try CSVParser.parse(csv)
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[1], ["3", "4"])
    }

    func testSkipsTrailingBlankRows() throws {
        let csv = "A,B\n1,2\n\n\n"
        let table = try CSVParser.parse(csv)
        XCTAssertEqual(table.rows.count, 1)
    }

    func testEmptyFileThrows() {
        XCTAssertThrowsError(try CSVParser.parse(""))
    }

    func testDetectsSemicolonDelimiter() {
        XCTAssertEqual(CSVParser.detectDelimiter("a;b;c\n1;2;3"), ";")
    }

    func testDetectsTabDelimiter() {
        XCTAssertEqual(CSVParser.detectDelimiter("a\tb\tc"), "\t")
    }

    func testParsesWithDetectedDelimiter() throws {
        let csv = "Date;Merchant;Amount\n2026-06-01;Swiggy;450"
        let table = try CSVParser.parse(csv, delimiter: ";")
        XCTAssertEqual(table.headers.count, 3)
        XCTAssertEqual(table.rows[0][1], "Swiggy")
    }
}
