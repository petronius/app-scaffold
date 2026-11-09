import Foundation
import CloudKit
import AppCore
import AppData

/// Keeps the store consistent across the user's devices through the CloudKit
/// **private database**, with `CKSyncEngine` doing the scheduling, batching,
/// change tokens, push subscription and retries. No server of our own;
/// nothing leaves the user's iCloud account.
///
/// One record per fact, in one custom zone, typed by `SyncRecordType`. The
/// store says which rows moved since this device last pushed them; a fetched
/// record is judged by `SyncResolution` against the local row and applied
/// stamped with the remote's own time, so it never bounces back. Saves carry
/// the last-seen change tag, so a lost race is a conflict to resolve, never a
/// silent overwrite. The phone and the watch each run one, as peers.
///
/// `spec/capabilities/CloudSync/README.md` describes the design and the
/// checklist for syncing a new type.
public actor CloudSync: CKSyncEngineDelegate {
    public struct Configuration: Sendable {
        public var containerID: String
        public var zoneName: String

        public init(containerID: String, zoneName: String = "AppZone") {
            self.containerID = containerID
            self.zoneName = zoneName
        }
    }

    public enum Status: Sendable, Equatable {
        case off
        case noAccount
        /// Running, with no pass finished yet.
        case waiting
        case syncing
        case synced(Date)
        case failed(String)
        /// The user deleted the app's data from iCloud. Sync stops; the
        /// device keeps its copy.
        case deletedInICloud
    }

    /// What a fetch changed, so the app refreshes only that.
    public struct Report: Sendable, Equatable {
        public var applied = 0
        public var changedTypes: Set<SyncRecordType> = []
        /// Records written by a newer build, left untouched.
        public var skippedNewer = 0
    }

    private let database: AppDatabase
    private let configuration: Configuration
    private let zoneID: CKRecordZone.ID
    private let onStatus: @Sendable (Status) -> Void
    private let onApplied: @Sendable (Report) -> Void

    private var engine: CKSyncEngine?
    private var deviceID = ""
    private var status: Status = .off {
        didSet { if status != oldValue { onStatus(status) } }
    }
    /// A per-record failure from the last send, kept until a send succeeds.
    private var sendFailure: String?

    public init(database: AppDatabase, configuration: Configuration,
                onStatus: @escaping @Sendable (Status) -> Void,
                onApplied: @escaping @Sendable (Report) -> Void) {
        self.database = database
        self.configuration = configuration
        self.zoneID = CKRecordZone.ID(zoneName: configuration.zoneName, ownerName: CKCurrentUserDefaultName)
        self.onStatus = onStatus
        self.onApplied = onApplied
    }

    // MARK: - Control

    /// Starts syncing: restores the engine's saved state, queues every row
    /// that moved since the last push, and fetches.
    public func start() async {
        guard engine == nil else { return }
        let container = CKContainer(identifier: configuration.containerID)
        do {
            deviceID = try database.deviceID()
            let saved = try database.engineState()
            let state = saved.flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
            let engine = CKSyncEngine(CKSyncEngine.Configuration(
                database: container.privateCloudDatabase, stateSerialization: state, delegate: self))
            self.engine = engine
            if state == nil {
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            }
            enqueue(try database.pendingRecordNames(), on: engine)
            status = (try? await container.accountStatus()) == .available ? .waiting : .noAccount
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    /// Stops syncing. The engine's state stays saved, so a later `start`
    /// carries on from where this left off.
    public func stop() {
        engine = nil
        status = .off
    }

    /// Queue local edits for the next send. The engine sends on its own a
    /// moment later.
    public func push(_ recordNames: [String]) {
        guard let engine, !recordNames.isEmpty else { return }
        enqueue(recordNames, on: engine)
    }

    /// Fetch, then send, now: pull to refresh, and the app coming to the
    /// foreground.
    public func syncNow() async {
        guard let engine else { return }
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    // MARK: - CKSyncEngineDelegate

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            try? database.saveEngineState(try? JSONEncoder().encode(update.stateSerialization))

        case .accountChange(let change):
            handleAccountChange(change, engine: syncEngine)

        case .fetchedDatabaseChanges(let changes):
            handleDatabaseChanges(changes, engine: syncEngine)

        case .fetchedRecordZoneChanges(let changes):
            handleFetched(changes, engine: syncEngine)

        case .sentRecordZoneChanges(let sent):
            handleSent(sent, engine: syncEngine)

        case .sentDatabaseChanges(let sent):
            for failure in sent.failedZoneSaves {
                status = .failed(Self.describe(failure.error))
            }

        case .willFetchChanges, .willSendChanges:
            // A stopped engine's last events change nothing on screen.
            if engine != nil { status = .syncing }

        case .didFetchChanges, .didSendChanges:
            if engine == nil {
                break
            } else if let sendFailure {
                status = .failed(sendFailure)
            } else {
                status = .synced(Date())
            }

        case .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break

        @unknown default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                          syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !changes.isEmpty else { return nil }
        let database = database
        let deviceID = deviceID
        let zoneID = zoneID
        // The engine takes as many as fit in one request and asks again for
        // the rest.
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            guard let outgoing = try? database.outgoing(recordName: recordID.recordName, deviceID: deviceID) else {
                // The row is gone (a store reset): nothing to send.
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            return RecordMapping.record(for: outgoing.envelope, zoneID: zoneID, systemFields: outgoing.systemFields)
        }
    }

    // MARK: - Events

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange, engine: CKSyncEngine) {
        switch change.changeType {
        case .signIn:
            // Everything this device holds goes up to the account it now
            // has; conflicts with what is already there resolve as usual.
            try? database.resetSyncMetadata()
            restart()
        case .switchAccounts:
            // Local data stays: it is the user's, on their device. Nothing
            // learned from the old account carries over.
            try? database.resetSyncMetadata()
            restart()
        case .signOut:
            try? database.resetSyncMetadata()
            status = .noAccount
        @unknown default:
            break
        }
    }

    private func handleDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges, engine: CKSyncEngine) {
        for deletion in changes.deletions where deletion.zoneID == zoneID {
            try? database.resetSyncMetadata()
            switch deletion.reason {
            case .encryptedDataReset:
                // The user reset their iCloud Keychain, and with it the keys
                // of the encrypted fields. Apple's advice: upload again.
                restart()
            default:
                // The user deleted the app's data from iCloud. Re-uploading
                // would undo their choice, so sync stops and the device keeps
                // its copy; turning sync on again uploads it.
                self.engine = nil
                status = .deletedInICloud
            }
        }
    }

    private func handleFetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, engine: CKSyncEngine) {
        var report = Report()
        for modification in changes.modifications {
            resolve(modification.record, engine: engine, report: &report)
        }
        for deletion in changes.deletions {
            guard SyncRecordType.parse(recordName: deletion.recordID.recordName) != nil else { continue }
            try? database.removeLocal(recordName: deletion.recordID.recordName)
            report.applied += 1
        }
        if report.applied > 0 || report.skippedNewer > 0 { onApplied(report) }
    }

    /// One fetched (or conflicting server) record against its local row.
    private func resolve(_ record: CKRecord, engine: CKSyncEngine, report: inout Report) {
        guard let remote = RecordMapping.envelope(from: record) else { return }
        let systemFields = RecordMapping.systemFields(of: record)
        let local = try? database.localStamp(recordName: remote.recordName)
        switch SyncResolution.decide(remote: remote, local: local, deviceID: deviceID) {
        case .applyRemote:
            if (try? database.apply(remote, systemFields: systemFields)) == true {
                report.applied += 1
                report.changedTypes.insert(remote.type)
            }
        case .keepLocal:
            // The next save must present this change tag to overwrite it.
            try? database.saveSystemFields(recordName: remote.recordName, type: remote.type, systemFields: systemFields)
            enqueue([remote.recordName], on: engine)
        case .alreadySame:
            try? database.markSynced(recordName: remote.recordName, type: remote.type,
                                     editedAt: max(remote.editedAt, local?.editedAt ?? remote.editedAt),
                                     systemFields: systemFields)
        case .unsupportedSchema:
            report.skippedNewer += 1
        }
    }

    private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, engine: CKSyncEngine) {
        var failure: String?
        for record in sent.savedRecords {
            guard let envelope = RecordMapping.envelope(from: record) else { continue }
            try? database.markSynced(recordName: envelope.recordName, type: envelope.type,
                                     editedAt: envelope.editedAt, systemFields: RecordMapping.systemFields(of: record))
        }
        var report = Report()
        for failed in sent.failedRecordSaves {
            let recordName = failed.record.recordID.recordName
            guard let type = SyncRecordType.parse(recordName: recordName)?.type else { continue }
            switch failed.error.code {
            case .serverRecordChanged:
                // Another device saved first: judge its copy like a fetched
                // record. The engine does not retry this on its own.
                if let server = failed.error.serverRecord {
                    resolve(server, engine: engine, report: &report)
                }
            case .zoneNotFound:
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                try? database.saveSystemFields(recordName: recordName, type: type, systemFields: nil)
                enqueue([recordName], on: engine)
            case .unknownItem:
                // Our change tag names a record the server no longer has.
                try? database.saveSystemFields(recordName: recordName, type: type, systemFields: nil)
                enqueue([recordName], on: engine)
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited:
                // Transient: the engine retries these itself.
                break
            default:
                // A type missing from the production schema, a payload over
                // the size limit: the row stays pending and the status says
                // why.
                failure = Self.describe(failed.error, recordName: recordName)
            }
        }
        if report.applied > 0 { onApplied(report) }
        sendFailure = failure
    }

    // MARK: - Helpers

    private func enqueue(_ recordNames: [String], on engine: CKSyncEngine) {
        let existing = Set(engine.state.pendingRecordZoneChanges)
        let changes = recordNames
            .map { CKSyncEngine.PendingRecordZoneChange.saveRecord(CKRecord.ID(recordName: $0, zoneID: zoneID)) }
            .filter { !existing.contains($0) }
        if !changes.isEmpty { engine.state.add(pendingRecordZoneChanges: changes) }
    }

    /// A new engine from no saved state, after the account changed under the
    /// old one. Runs after the current event has returned.
    private func restart() {
        engine = nil
        Task { await self.start() }
    }

    static func describe(_ error: any Error, recordName: String? = nil) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        var text = ck.localizedDescription + " (CKError \(ck.code.rawValue))"
        if let recordName { text += " on \(recordName)" }
        return text
    }
}
