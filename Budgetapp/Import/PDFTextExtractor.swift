import Foundation
import PDFKit

/// Wraps PDFKit to pull selectable text out of a statement PDF. Detects
/// scanned/image-only PDFs (no extractable text) and reports them clearly so
/// the UI can explain that OCR is not implemented.
enum PDFTextExtractor {

    struct Extraction {
        var text: String
        var pageCount: Int
        /// True when the document has pages but no meaningful selectable text,
        /// i.e. it is almost certainly scanned/image-only.
        var looksScanned: Bool
    }

    static func extract(from url: URL) throws -> Extraction {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else {
            throw ImportError.unreadableFile
        }
        return extract(from: document)
    }

    static func extract(from document: PDFDocument) -> Extraction {
        let pageCount = document.pageCount
        var collected = ""
        for index in 0..<pageCount {
            if let page = document.page(at: index), let pageText = page.string {
                collected += pageText
                collected += "\n"
            }
        }

        let meaningful = collected.trimmingCharacters(in: .whitespacesAndNewlines)
        // Heuristic: a real text statement yields a few hundred characters at
        // least. Almost-empty extraction from a multi-page doc => scanned.
        let looksScanned = pageCount > 0 && meaningful.count < 40
        return Extraction(text: collected, pageCount: pageCount, looksScanned: looksScanned)
    }
}
