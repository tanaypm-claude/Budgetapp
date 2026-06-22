import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#5E7CE2",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() { updatedAt = .now }
}
