import Foundation

/// A small RFC 4180-style CSV parser: handles quoted fields, escaped quotes
/// (`""`), embedded commas and newlines, and `\r\n` / `\n` line endings.
/// Pure and synchronous so it is trivially testable.
enum CSVParser {

    /// Parse raw CSV text into a `CSVTable`. The first non-empty line is treated
    /// as the header row.
    static func parse(_ text: String, delimiter: Character = ",") throws -> CSVTable {
        let records = parseRecords(text, delimiter: delimiter)
        guard !records.isEmpty else { throw ImportError.emptyFile }

        // Skip fully blank leading records.
        var rows = records.drop(while: { $0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } })
        guard let header = rows.first else { throw ImportError.noColumnsDetected }
        rows = rows.dropFirst()

        let headers = header.map { $0.trimmingCharacters(in: .whitespaces) }
        guard headers.contains(where: { !$0.isEmpty }) else { throw ImportError.noColumnsDetected }

        // Drop trailing blank rows.
        let dataRows = rows.filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        return CSVTable(headers: headers, rows: Array(dataRows))
    }

    /// Detect the most likely delimiter by sampling the first line.
    static func detectDelimiter(_ text: String) -> Character {
        let firstLine = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).first.map(String.init) ?? text
        let candidates: [Character] = [",", ";", "\t", "|"]
        var best: Character = ","
        var bestCount = -1
        for candidate in candidates {
            let count = firstLine.filter { $0 == candidate }.count
            if count > bestCount {
                bestCount = count
                best = candidate
            }
        }
        return best
    }

    // MARK: Core state machine

    static func parseRecords(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var field = ""
        var insideQuotes = false
        var sawAnyChar = false

        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let char = chars[i]
            sawAnyChar = true

            if insideQuotes {
                if char == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    insideQuotes = true
                case delimiter:
                    currentRecord.append(field)
                    field = ""
                case "\n":
                    currentRecord.append(field)
                    records.append(currentRecord)
                    currentRecord = []
                    field = ""
                case "\r":
                    // Handle \r\n and lone \r as line breaks.
                    currentRecord.append(field)
                    records.append(currentRecord)
                    currentRecord = []
                    field = ""
                    if i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                default:
                    field.append(char)
                }
            }
            i += 1
        }

        // Flush the final field/record if the file didn't end with a newline.
        if sawAnyChar && (!field.isEmpty || !currentRecord.isEmpty) {
            currentRecord.append(field)
            records.append(currentRecord)
        }

        return records
    }
}
