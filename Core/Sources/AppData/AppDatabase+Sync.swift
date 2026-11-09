import Foundation
import GRDB
import AppCore

/// What the sync reads from and writes to the store. Nothing here talks to
/// CloudKit: `AppSync` turns these into records and back.
extension AppDatabase {

    /// The outgoing side of one record: its envelope, and the server's
    /// system fields as this device last saw them (nil for a record never
    /// saved, which CloudKit then creates).
    public struct Outgoing: Sendable {
        public var envelope: SyncEnvelope
        public var systemFields: Data?
    }

    // MARK: Install state

    /// This install's id, minted on first use. The tie-break between two
    /// edits with the same stamp, and the `editedBy` of every push.
    public func deviceID() throws -> String {
        try writer.write { db in
            if let id = try String.fetchOne(db, sql: "SELECT deviceID FROM syncState WHERE id = 1") { return id }
            let id = UUID().uuidString
            try db.execute(sql: "INSERT INTO syncState (id, deviceID) VALUES (1, ?)", arguments: [id])
            return id
        }
    }

    /// CKSyncEngine's own state (change tokens, pending changes), archived.
    public func engineState() throws -> Data? {
        try writer.read { db in try Data.fetchOne(db, sql: "SELECT engineState FROM syncState WHERE id = 1") }
    }

    public func saveEngineState(_ data: Data?) throws {
        _ = try deviceID()
        try writer.write { db in
            try db.execute(sql: "UPDATE syncState SET engineState = ? WHERE id = 1", arguments: [data])
        }
    }

    // MARK: Outgoing

    /// Every record whose row moved since this device last pushed or applied
    /// it, tombstones included.
    public func pendingRecordNames() throws -> [String] {
        try writer.read { db in
            var names: [String] = []
            for type in SyncRecordType.allCases {
                let keys = try String.fetchAll(db, sql: """
                    SELECT t.id FROM \(type.table) t
                    LEFT JOIN syncMeta m ON m.recordName = ? || t.id
                    WHERE m.pushedAt IS NULL OR t.updatedAt > m.pushedAt
                    """, arguments: [type.namePrefix + "-"])
                names += keys.map(type.recordName(key:))
            }
            return names
        }
    }

    /// The record to push for a name, or nil when the row no longer exists.
    public func outgoing(recordName: String, deviceID: String) throws -> Outgoing? {
        guard let (type, key) = SyncRecordType.parse(recordName: recordName), let key else { return nil }
        return try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT payload, updatedAt, deletedAt FROM \(type.table) WHERE id = ?
                """, arguments: [key]) else { return nil }
            let deleted = (row["deletedAt"] as SyncStamp?) != nil
            let envelope = SyncEnvelope(type: type, recordName: recordName,
                                        payload: deleted ? nil : row["payload"],
                                        editedAt: row["updatedAt"], editedBy: deviceID, deleted: deleted)
            let systemFields = try Data.fetchOne(db, sql: "SELECT systemFields FROM syncMeta WHERE recordName = ?",
                                                 arguments: [recordName])
            return Outgoing(envelope: envelope, systemFields: systemFields)
        }
    }

    // MARK: Incoming

    /// The local row's stamp for a fetched record, or nil when this device
    /// has never held it.
    public func localStamp(recordName: String) throws -> LocalSyncStamp? {
        guard let (type, key) = SyncRecordType.parse(recordName: recordName), let key else { return nil }
        return try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT payload, updatedAt, deletedAt FROM \(type.table) WHERE id = ?
                """, arguments: [key]) else { return nil }
            let deleted = (row["deletedAt"] as SyncStamp?) != nil
            return LocalSyncStamp(editedAt: row["updatedAt"], deleted: deleted, payload: deleted ? nil : row["payload"])
        }
    }

    /// Writes a fetched record that won (`SyncResolution.applyRemote`),
    /// stamped with the remote's own time so it never bounces back, and
    /// marks it synced. Returns false for a payload this build cannot read;
    /// the row is then left as it was.
    @discardableResult
    public func apply(_ envelope: SyncEnvelope, systemFields: Data?) throws -> Bool {
        guard let (type, key) = SyncRecordType.parse(recordName: envelope.recordName), let key else { return false }
        return try writer.write { db in
            switch type {
            case .item:
                if envelope.deleted {
                    // A tombstone for a row this device never held still
                    // lands, so a later stale copy cannot restore it.
                    let payload = try Data.fetchOne(db, sql: "SELECT payload FROM item WHERE id = ?", arguments: [key])
                    if let payload, let item = try? SyncCoding.decode(Item.self, from: payload) {
                        try Self.writeItem(db, item: item, payload: payload,
                                           updatedAt: envelope.editedAt, deletedAt: envelope.editedAt)
                    } else if let id = UUID(uuidString: key) {
                        let placeholder = Item(id: id, title: "", createdAt: Date(timeIntervalSince1970: 0))
                        try Self.writeItem(db, item: placeholder, payload: try SyncCoding.encode(placeholder),
                                           updatedAt: envelope.editedAt, deletedAt: envelope.editedAt)
                    }
                } else {
                    guard let payload = envelope.payload,
                          let item = try? SyncCoding.decode(Item.self, from: payload) else { return false }
                    try Self.writeItem(db, item: item, payload: payload, updatedAt: envelope.editedAt, deletedAt: nil)
                }
            }
            try Self.writeMeta(db, recordName: envelope.recordName, type: type,
                               pushedAt: envelope.editedAt, systemFields: systemFields)
            return true
        }
    }

    /// After a successful save, or a fetch that found both sides the same:
    /// this stamp is on the server, and these are the record's system fields.
    public func markSynced(recordName: String, type: SyncRecordType, editedAt: SyncStamp, systemFields: Data?) throws {
        try writer.write { db in
            let previous = try SyncStamp.fetchOne(db, sql: "SELECT pushedAt FROM syncMeta WHERE recordName = ?",
                                                  arguments: [recordName])
            try Self.writeMeta(db, recordName: recordName, type: type,
                               pushedAt: max(previous ?? editedAt, editedAt), systemFields: systemFields)
        }
    }

    /// Remember the server's copy of a record without changing what was
    /// pushed: the local row won a conflict, and the next save must present
    /// this change tag.
    public func saveSystemFields(recordName: String, type: SyncRecordType, systemFields: Data?) throws {
        try writer.write { db in
            try db.execute(sql: """
                INSERT INTO syncMeta (recordName, recordType, systemFields) VALUES (?, ?, ?)
                ON CONFLICT(recordName) DO UPDATE SET systemFields = excluded.systemFields
                """, arguments: [recordName, type.rawValue, systemFields])
        }
    }

    /// A record deleted on the server outright (the app itself only ever
    /// writes tombstones): the local row and its book-keeping go too.
    public func removeLocal(recordName: String) throws {
        guard let (type, key) = SyncRecordType.parse(recordName: recordName), let key else { return }
        try writer.write { db in
            try db.execute(sql: "DELETE FROM \(type.table) WHERE id = ?", arguments: [key])
            try db.execute(sql: "DELETE FROM syncMeta WHERE recordName = ?", arguments: [recordName])
        }
    }

    /// Forget everything this device knows about the server (account change,
    /// iCloud data deleted): every row is pending again, and every save
    /// starts from no change tag. Local data is untouched.
    public func resetSyncMetadata() throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM syncMeta")
            try db.execute(sql: "UPDATE syncState SET engineState = NULL")
        }
    }

    // MARK: Helpers

    static func writeMeta(_ db: Database, recordName: String, type: SyncRecordType,
                          pushedAt: SyncStamp, systemFields: Data?) throws {
        try db.execute(sql: """
            INSERT INTO syncMeta (recordName, recordType, pushedAt, systemFields) VALUES (?, ?, ?, ?)
            ON CONFLICT(recordName) DO UPDATE SET
                recordType = excluded.recordType, pushedAt = excluded.pushedAt,
                systemFields = COALESCE(excluded.systemFields, syncMeta.systemFields)
            """, arguments: [recordName, type.rawValue, pushedAt, systemFields])
    }
}

extension SyncRecordType {
    /// The local table that holds this type's rows. Every synced table has
    /// `id`, `payload`, `updatedAt` and `deletedAt`.
    var table: String {
        switch self {
        case .item: "item"
        }
    }
}
