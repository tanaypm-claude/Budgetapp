import Foundation
import SwiftData

/// Records a single import run so transactions can be traced back to their
/// origin file and an import can be undone wholesale.
@Model
final class ImportBatch {
    @Attribute(.unique) var id: UUID
    var filename: String
    var fileTypeRaw: String
    var importedAt: Date
    var rowCount: Int
    var statusRaw: String
    /// Number of rows skipped as duplicates during this import.
    var duplicateCount: Int
    /// Number of rows that landed in the review queue.
    var needsReviewCount: Int
    var note: String

    var fileType: ImportFileType {
        get { ImportFileType(rawValue: fileTypeRaw) ?? .csv }
        set { fileTypeRaw = newValue.rawValue }
    }

    var status: ImportStatus {
        get { ImportStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        filename: String,
        fileType: ImportFileType,
        importedAt: Date = .now,
        rowCount: Int = 0,
        status: ImportStatus = .completed,
        duplicateCount: Int = 0,
        needsReviewCount: Int = 0,
        note: String = ""
    ) {
        self.id = id
        self.filename = filename
        self.fileTypeRaw = fileType.rawValue
        self.importedAt = importedAt
        self.rowCount = rowCount
        self.statusRaw = status.rawValue
        self.duplicateCount = duplicateCount
        self.needsReviewCount = needsReviewCount
        self.note = note
    }
}
