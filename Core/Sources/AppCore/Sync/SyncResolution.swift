import Foundation

/// An edit stamp: whole milliseconds since 1970, UTC. An integer, so a stamp
/// survives SQLite and CloudKit unchanged and two stamps compare exactly.
public typealias SyncStamp = Int64

public extension SyncStamp {
    init(date: Date) { self = SyncStamp((date.timeIntervalSince1970 * 1000).rounded(.down)) }
    var date: Date { Date(timeIntervalSince1970: Double(self) / 1000) }
}

/// One synced fact as it travels, without CloudKit: what the store hands the
/// sync to push, and what a fetched record becomes before it is judged.
public struct SyncEnvelope: Sendable, Equatable {
    public var type: SyncRecordType
    public var recordName: String
    /// The model's JSON (`SyncCoding`); nil on a tombstone.
    public var payload: Data?
    /// When the user made the edit, as the writing device's store stamped it.
    /// Never invented by the sync.
    public var editedAt: SyncStamp
    /// The writing install's id: the tie-break when two stamps are equal.
    public var editedBy: String
    /// The payload format. A record stamped higher than this build's
    /// `SyncResolution.schemaVersion` is left alone.
    public var schemaVersion: Int
    public var deleted: Bool

    public init(type: SyncRecordType, recordName: String, payload: Data?, editedAt: SyncStamp,
                editedBy: String, schemaVersion: Int = SyncResolution.schemaVersion, deleted: Bool) {
        self.type = type
        self.recordName = recordName
        self.payload = payload
        self.editedAt = editedAt
        self.editedBy = editedBy
        self.schemaVersion = schemaVersion
        self.deleted = deleted
    }
}

/// The local row's side of a comparison.
public struct LocalSyncStamp: Sendable, Equatable {
    public var editedAt: SyncStamp
    public var deleted: Bool
    public var payload: Data?

    public init(editedAt: SyncStamp, deleted: Bool, payload: Data?) {
        self.editedAt = editedAt
        self.deleted = deleted
        self.payload = payload
    }
}

/// The rules that decide between a fetched record and the local row. Pure,
/// so every case is a unit test.
public enum SyncResolution {
    /// The payload format this build writes and reads. Raise it only for a
    /// change an older build would misread; an added optional field does not
    /// need it, since older builds decode leniently and ignore the key.
    public static let schemaVersion = 1

    public enum Decision: Sendable, Equatable {
        /// Write the remote record locally, stamped with its own time.
        case applyRemote
        /// The local row wins; the next push overwrites the server's copy.
        case keepLocal
        /// Both sides hold the same fact; only the book-keeping moves.
        case alreadySame
        /// Written by a newer build: left untouched.
        case unsupportedSchema
    }

    /// Newer edit wins. Equal stamps go to the larger writer id, so two
    /// devices always pick the same winner. A tombstone is a fact under the
    /// same rule: a newer deletion removes, a newer live record restores.
    public static func decide(remote: SyncEnvelope, local: LocalSyncStamp?, deviceID: String) -> Decision {
        if remote.schemaVersion > schemaVersion { return .unsupportedSchema }
        guard let local else { return .applyRemote }
        if remote.deleted == local.deleted && (remote.deleted || remote.payload == local.payload) {
            return .alreadySame
        }
        if remote.editedAt != local.editedAt {
            return remote.editedAt > local.editedAt ? .applyRemote : .keepLocal
        }
        return remote.editedBy > deviceID ? .applyRemote : .keepLocal
    }
}

/// The one JSON form of a synced payload: sorted keys and dates as seconds,
/// so the same model always encodes to the same bytes and two copies of a
/// fact compare equal byte for byte.
public enum SyncCoding {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(type, from: data)
    }
}
