import Foundation
import Testing
@testable import AppData
import AppCore

struct AppDatabaseTests {
    let t0 = Date(timeIntervalSince1970: 1_762_700_000)

    @Test func itemsSaveAndReadNewestFirst() throws {
        let db = try AppDatabase.inMemory()
        let older = Item(title: "Older", createdAt: t0)
        let newer = Item(title: "Newer", createdAt: t0.addingTimeInterval(60))
        try db.save(older, now: t0)
        try db.save(newer, now: t0)
        #expect(try db.items().map(\.title) == ["Newer", "Older"])
        #expect(try db.summary() == ItemsSummary(count: 2, latestTitles: ["Newer", "Older"]))
    }

    @Test func aDeleteLeavesATombstoneThatSyncs() throws {
        let db = try AppDatabase.inMemory()
        let item = Item(title: "Milk", createdAt: t0)
        let name = try db.save(item, now: t0)
        try db.markSynced(recordName: name, type: .item, editedAt: SyncStamp(date: t0), systemFields: nil)
        #expect(try db.pendingRecordNames().isEmpty)

        #expect(try db.deleteItem(id: item.id, now: t0.addingTimeInterval(1)) == name)
        #expect(try db.items().isEmpty)
        #expect(try db.pendingRecordNames() == [name])
        let outgoing = try #require(try db.outgoing(recordName: name, deviceID: "me"))
        #expect(outgoing.envelope.deleted)
        #expect(outgoing.envelope.payload == nil)
        // Deleting what is already gone changes nothing.
        #expect(try db.deleteItem(id: item.id, now: t0.addingTimeInterval(2)) == nil)
    }

    @Test func anEditIsNeverStampedBeforeTheLastOne() throws {
        let db = try AppDatabase.inMemory()
        var item = Item(title: "Milk", createdAt: t0)
        let name = try db.save(item, now: t0)
        item.title = "Oat milk"
        // The device clock moved back an hour.
        try db.save(item, now: t0.addingTimeInterval(-3600))
        let stamp = try #require(try db.localStamp(recordName: name))
        #expect(stamp.editedAt == SyncStamp(date: t0) + 1)
    }

    @Test func anAppliedRecordIsSyncedAndNotPushedBack() throws {
        let db = try AppDatabase.inMemory()
        let item = Item(title: "From the phone", createdAt: t0)
        let name = SyncRecordType.item.recordName(key: item.id.uuidString)
        let envelope = SyncEnvelope(type: .item, recordName: name, payload: try SyncCoding.encode(item),
                                    editedAt: 42, editedBy: "phone", deleted: false)
        #expect(try db.apply(envelope, systemFields: Data([1, 2, 3])))
        #expect(try db.items() == [item])
        #expect(try db.pendingRecordNames().isEmpty)
        #expect(try db.outgoing(recordName: name, deviceID: "watch")?.systemFields == Data([1, 2, 3]))
    }

    @Test func aTombstoneForAnUnknownRowStillLands() throws {
        let db = try AppDatabase.inMemory()
        let id = UUID()
        let name = SyncRecordType.item.recordName(key: id.uuidString)
        let tombstone = SyncEnvelope(type: .item, recordName: name, payload: nil, editedAt: 50, editedBy: "phone", deleted: true)
        #expect(try db.apply(tombstone, systemFields: nil))
        #expect(try db.items().isEmpty)
        #expect(try db.localStamp(recordName: name) == LocalSyncStamp(editedAt: 50, deleted: true, payload: nil))
    }

    @Test func anUnreadablePayloadIsRefused() throws {
        let db = try AppDatabase.inMemory()
        let name = SyncRecordType.item.recordName(key: UUID().uuidString)
        let broken = SyncEnvelope(type: .item, recordName: name, payload: Data("{".utf8), editedAt: 1, editedBy: "x", deleted: false)
        #expect(try db.apply(broken, systemFields: nil) == false)
        #expect(try db.items().isEmpty)
    }

    @Test func resettingTheSyncLeavesDataAndMakesEverythingPending() throws {
        let db = try AppDatabase.inMemory()
        let id = try db.deviceID()
        let name = try db.save(Item(title: "Milk", createdAt: t0), now: t0)
        try db.markSynced(recordName: name, type: .item, editedAt: SyncStamp(date: t0), systemFields: Data([9]))
        try db.saveEngineState(Data([7]))
        try db.resetSyncMetadata()
        #expect(try db.items().count == 1)
        #expect(try db.pendingRecordNames() == [name])
        #expect(try db.engineState() == nil)
        #expect(try db.deviceID() == id)
    }

    @Test func theStreamFollowsEveryWrite() async throws {
        let db = try AppDatabase.inMemory()
        var iterator = db.itemsStream().makeAsyncIterator()
        #expect(try await iterator.next() == [])
        try db.save(Item(title: "Milk", createdAt: t0), now: t0)
        #expect(try await iterator.next()?.map(\.title) == ["Milk"])
    }
}
