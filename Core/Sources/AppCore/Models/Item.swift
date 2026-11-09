import Foundation

/// The example record: one thing the user writes down. Replace it with the
/// app's own models; keep the shape.
///
/// A domain model carries no storage or sync fields. The store keeps the
/// edit stamp and the tombstone beside the row (`AppData`), and the sync
/// carries them in the record's envelope (`SyncEnvelope`), so a model can
/// change without touching either.
public struct Item: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, notes: String = "", createdAt: Date) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
    }

    /// The title with surrounding white space removed. Empty means the user
    /// left it blank; the view shows the copy table's placeholder instead.
    public var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// What a widget or complication shows: a count and the newest titles. One
/// read, so every surface that shows the count agrees with every other.
public struct ItemsSummary: Sendable, Equatable {
    public var count: Int
    /// Newest first, at most `ItemsSummary.titleLimit`.
    public var latestTitles: [String]

    public static let titleLimit = 3
    public static let empty = ItemsSummary(count: 0, latestTitles: [])

    public init(count: Int, latestTitles: [String]) {
        self.count = count
        self.latestTitles = latestTitles
    }
}
