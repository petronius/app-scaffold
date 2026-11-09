import Foundation
import CloudKit
import AppCore

/// Envelopes to CloudKit records and back. Every record type carries the
/// same fields, so one mapping serves them all:
///
/// | Field | Type | Meaning |
/// |---|---|---|
/// | `payload` | Bytes, encrypted | The model's JSON; absent on a tombstone |
/// | `editedAt` | Int64 | The store's edit stamp, in milliseconds |
/// | `editedBy` | String | The writing install's id |
/// | `schemaVersion` | Int64 | The payload format |
/// | `deleted` | Int64 | 1 for a tombstone |
///
/// The payload is in `encryptedValues`: end-to-end encrypted with a key in
/// the user's iCloud Keychain, so not even Apple can read it. The other
/// fields carry no content. `Scripts/cloudkit-schema.ckdb` declares the same.
public enum RecordMapping {
    public enum Field {
        public static let payload = "payload"
        public static let editedAt = "editedAt"
        public static let editedBy = "editedBy"
        public static let schemaVersion = "schemaVersion"
        public static let deleted = "deleted"
    }

    /// The record to save for an envelope, built on the server's system
    /// fields when this device has them, so the save presents the change tag
    /// it last saw and a lost race comes back as a conflict.
    public static func record(for envelope: SyncEnvelope, zoneID: CKRecordZone.ID, systemFields: Data?) -> CKRecord {
        let record = systemFields.flatMap(Self.record(fromSystemFields:))
            ?? CKRecord(recordType: envelope.type.rawValue,
                        recordID: CKRecord.ID(recordName: envelope.recordName, zoneID: zoneID))
        record.encryptedValues[Field.payload] = envelope.payload
        record[Field.editedAt] = envelope.editedAt
        record[Field.editedBy] = envelope.editedBy
        record[Field.schemaVersion] = Int64(envelope.schemaVersion)
        record[Field.deleted] = Int64(envelope.deleted ? 1 : 0)
        return record
    }

    /// A fetched record as an envelope. Nil for a record type this build
    /// does not know, or one missing its stamp.
    public static func envelope(from record: CKRecord) -> SyncEnvelope? {
        guard let type = SyncRecordType(rawValue: record.recordType),
              let editedAt = record[Field.editedAt] as? Int64 else { return nil }
        let deleted = (record[Field.deleted] as? Int64 ?? 0) != 0
        return SyncEnvelope(type: type, recordName: record.recordID.recordName,
                            payload: deleted ? nil : record.encryptedValues[Field.payload] as? Data,
                            editedAt: editedAt,
                            editedBy: record[Field.editedBy] as? String ?? "",
                            schemaVersion: Int(record[Field.schemaVersion] as? Int64 ?? 1),
                            deleted: deleted)
    }

    /// The record's system fields (identity, change tag), archived without
    /// its values.
    public static func systemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    public static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}
