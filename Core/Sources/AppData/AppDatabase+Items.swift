import Foundation
import GRDB
import AppCore

/// The example table. A new model copies this file: reads that skip
/// tombstones, writes that stamp `updatedAt` in the same statement as the
/// edit, and a delete that leaves a tombstone.
extension AppDatabase {

    // MARK: Reads

    /// Every live item, newest first.
    public func items() throws -> [Item] {
        try writer.read { db in try Self.fetchItems(db) }
    }

    public func item(id: UUID) throws -> Item? {
        try writer.read { db in
            let payload = try Data.fetchOne(db, sql: "SELECT payload FROM item WHERE id = ? AND deletedAt IS NULL",
                                            arguments: [id.uuidString])
            return try payload.map { try SyncCoding.decode(Item.self, from: $0) }
        }
    }

    /// The count and newest titles the widgets show.
    public func summary() throws -> ItemsSummary {
        try writer.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item WHERE deletedAt IS NULL") ?? 0
            let titles = try String.fetchAll(db, sql: """
                SELECT title FROM item WHERE deletedAt IS NULL ORDER BY createdAt DESC LIMIT ?
                """, arguments: [ItemsSummary.titleLimit])
            return ItemsSummary(count: count, latestTitles: titles)
        }
    }

    /// Every live item, newest first, and again after each change to the
    /// table, whether the user or the sync made it.
    public func itemsStream() -> AsyncThrowingStream<[Item], any Error> {
        let observation = ValueObservation.tracking { db in try Self.fetchItems(db) }
        let values = observation.values(in: writer)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await items in values { continuation.yield(items) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Writes

    /// Inserts or updates an item, stamped as edited `now`. Returns the
    /// record name the sync must push.
    @discardableResult
    public func save(_ item: Item, now: Date = Date()) throws -> String {
        let payload = try SyncCoding.encode(item)
        try writer.write { db in
            let previous = try SyncStamp.fetchOne(db, sql: "SELECT updatedAt FROM item WHERE id = ?",
                                                  arguments: [item.id.uuidString])
            try Self.writeItem(db, item: item, payload: payload,
                               updatedAt: Self.stamp(now, after: previous), deletedAt: nil)
        }
        return SyncRecordType.item.recordName(key: item.id.uuidString)
    }

    /// Marks an item deleted, stamped `now`. The row stays as a tombstone,
    /// so the deletion reaches every device and an older copy elsewhere
    /// cannot bring it back. Returns the record name to push, or nil when
    /// there was no live item.
    @discardableResult
    public func deleteItem(id: UUID, now: Date = Date()) throws -> String? {
        try writer.write { db in
            guard let previous = try SyncStamp.fetchOne(db, sql: """
                SELECT updatedAt FROM item WHERE id = ? AND deletedAt IS NULL
                """, arguments: [id.uuidString]) else { return nil }
            let stamp = Self.stamp(now, after: previous)
            try db.execute(sql: "UPDATE item SET updatedAt = ?, deletedAt = ? WHERE id = ?",
                           arguments: [stamp, stamp, id.uuidString])
            return SyncRecordType.item.recordName(key: id.uuidString)
        }
    }

    // MARK: Shared with the sync

    static func fetchItems(_ db: Database) throws -> [Item] {
        try Data.fetchAll(db, sql: "SELECT payload FROM item WHERE deletedAt IS NULL ORDER BY createdAt DESC")
            .map { try SyncCoding.decode(Item.self, from: $0) }
    }

    static func writeItem(_ db: Database, item: Item, payload: Data, updatedAt: SyncStamp, deletedAt: SyncStamp?) throws {
        try db.execute(sql: """
            INSERT INTO item (id, payload, title, createdAt, updatedAt, deletedAt)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                payload = excluded.payload, title = excluded.title, createdAt = excluded.createdAt,
                updatedAt = excluded.updatedAt, deletedAt = excluded.deletedAt
            """, arguments: [item.id.uuidString, payload, item.trimmedTitle,
                             item.createdAt.timeIntervalSince1970, updatedAt, deletedAt])
    }
}
