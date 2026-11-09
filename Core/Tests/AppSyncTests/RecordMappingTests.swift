import Foundation
import CloudKit
import Testing
@testable import AppSync
import AppCore

struct RecordMappingTests {
    let zoneID = CKRecordZone.ID(zoneName: "AppZone", ownerName: CKCurrentUserDefaultName)

    @Test func anEnvelopeSurvivesTheRecord() throws {
        let envelope = SyncEnvelope(type: .item, recordName: "item-\(UUID().uuidString)", payload: Data("{}".utf8),
                                    editedAt: 1_762_700_000_123, editedBy: "phone", deleted: false)
        let record = RecordMapping.record(for: envelope, zoneID: zoneID, systemFields: nil)
        #expect(record.recordType == "Item")
        #expect(record.recordID.zoneID == zoneID)
        #expect(RecordMapping.envelope(from: record) == envelope)
    }

    @Test func aTombstoneCarriesNoPayload() throws {
        let envelope = SyncEnvelope(type: .item, recordName: "item-1", payload: nil, editedAt: 5, editedBy: "watch", deleted: true)
        let record = RecordMapping.record(for: envelope, zoneID: zoneID, systemFields: nil)
        let back = try #require(RecordMapping.envelope(from: record))
        #expect(back.deleted)
        #expect(back.payload == nil)
    }

    @Test func systemFieldsRebuildTheSameRecord() throws {
        let envelope = SyncEnvelope(type: .item, recordName: "item-2", payload: Data("x".utf8), editedAt: 1, editedBy: "a", deleted: false)
        let record = RecordMapping.record(for: envelope, zoneID: zoneID, systemFields: nil)
        let fields = RecordMapping.systemFields(of: record)
        let rebuilt = try #require(RecordMapping.record(fromSystemFields: fields))
        #expect(rebuilt.recordID == record.recordID)
        #expect(rebuilt.recordType == record.recordType)
        // Saving over system fields keeps the identity and sets the values.
        let resaved = RecordMapping.record(for: envelope, zoneID: zoneID, systemFields: fields)
        #expect(resaved.recordID == record.recordID)
        #expect(RecordMapping.envelope(from: resaved) == envelope)
    }

    @Test func anUnknownTypeIsSkipped() {
        let record = CKRecord(recordType: "FromANewerBuild", recordID: CKRecord.ID(recordName: "x-1", zoneID: zoneID))
        record[RecordMapping.Field.editedAt] = Int64(1)
        #expect(RecordMapping.envelope(from: record) == nil)
    }
}
