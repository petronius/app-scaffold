import Foundation
import Testing
@testable import AppCore

struct SyncResolutionTests {
    let payloadA = Data("a".utf8)
    let payloadB = Data("b".utf8)

    func remote(_ payload: Data?, at stamp: SyncStamp, by writer: String = "remote",
                deleted: Bool = false, schema: Int = SyncResolution.schemaVersion) -> SyncEnvelope {
        SyncEnvelope(type: .item, recordName: "item-1", payload: payload, editedAt: stamp,
                     editedBy: writer, schemaVersion: schema, deleted: deleted)
    }

    @Test func aRecordThisDeviceNeverHeldIsApplied() {
        #expect(SyncResolution.decide(remote: remote(payloadA, at: 10), local: nil, deviceID: "me") == .applyRemote)
    }

    @Test func theNewerEditWins() {
        let local = LocalSyncStamp(editedAt: 10, deleted: false, payload: payloadA)
        #expect(SyncResolution.decide(remote: remote(payloadB, at: 11), local: local, deviceID: "me") == .applyRemote)
        #expect(SyncResolution.decide(remote: remote(payloadB, at: 9), local: local, deviceID: "me") == .keepLocal)
    }

    @Test func equalStampsGoToTheLargerWriterOnBothDevices() {
        let local = LocalSyncStamp(editedAt: 10, deleted: false, payload: payloadA)
        // Device "b" sees "a"'s record and keeps its own; device "a" sees
        // "b"'s and applies it. Both end on "b"'s edit.
        #expect(SyncResolution.decide(remote: remote(payloadB, at: 10, by: "a"), local: local, deviceID: "b") == .keepLocal)
        #expect(SyncResolution.decide(remote: remote(payloadB, at: 10, by: "b"), local: local, deviceID: "a") == .applyRemote)
    }

    @Test func theSameFactNeedsOnlyBookKeeping() {
        let local = LocalSyncStamp(editedAt: 10, deleted: false, payload: payloadA)
        #expect(SyncResolution.decide(remote: remote(payloadA, at: 12), local: local, deviceID: "me") == .alreadySame)
        let tombstone = LocalSyncStamp(editedAt: 10, deleted: true, payload: nil)
        #expect(SyncResolution.decide(remote: remote(nil, at: 12, deleted: true), local: tombstone, deviceID: "me") == .alreadySame)
    }

    @Test func aNewerDeletionRemovesAndANewerEditRestores() {
        let live = LocalSyncStamp(editedAt: 10, deleted: false, payload: payloadA)
        #expect(SyncResolution.decide(remote: remote(nil, at: 11, deleted: true), local: live, deviceID: "me") == .applyRemote)
        let tombstone = LocalSyncStamp(editedAt: 10, deleted: true, payload: nil)
        #expect(SyncResolution.decide(remote: remote(payloadA, at: 11), local: tombstone, deviceID: "me") == .applyRemote)
        #expect(SyncResolution.decide(remote: remote(payloadA, at: 9), local: tombstone, deviceID: "me") == .keepLocal)
    }

    @Test func aRecordFromANewerBuildIsLeftAlone() {
        let newer = remote(payloadA, at: 99, schema: SyncResolution.schemaVersion + 1)
        #expect(SyncResolution.decide(remote: newer, local: nil, deviceID: "me") == .unsupportedSchema)
    }

    @Test func recordNamesRoundTrip() throws {
        let name = SyncRecordType.item.recordName(key: "ABC")
        #expect(name == "item-ABC")
        let parsed = try #require(SyncRecordType.parse(recordName: name))
        #expect(parsed.type == .item)
        #expect(parsed.key == "ABC")
        #expect(SyncRecordType.parse(recordName: "unknownType-1") == nil)
    }

    @Test func stampsAreWholeMilliseconds() {
        let date = Date(timeIntervalSince1970: 1_762_700_000.123_9)
        #expect(SyncStamp(date: date) == 1_762_700_000_123)
        #expect(SyncStamp(date: SyncStamp(1_762_700_000_123).date) == 1_762_700_000_123)
    }

    @Test func theSameModelEncodesToTheSameBytes() throws {
        let item = Item(id: UUID(), title: "Milk", notes: "Two litres", createdAt: Date(timeIntervalSince1970: 1_762_700_000.5))
        #expect(try SyncCoding.encode(item) == SyncCoding.encode(item))
        #expect(try SyncCoding.decode(Item.self, from: SyncCoding.encode(item)) == item)
    }
}
