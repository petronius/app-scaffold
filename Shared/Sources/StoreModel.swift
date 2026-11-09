import Foundation
import Observation
import WidgetKit
import AppCore
import AppData
import AppSync

/// The store and its sync as the views see them, on the phone and the watch
/// alike. Views read `items` and call the edit methods; they never open the
/// database or talk to CloudKit themselves.
///
/// `items` follows the store: it changes after a local edit and after the
/// sync applies a record from another device, with no refresh call.
@MainActor @Observable
final class StoreModel {
    private(set) var items: [Item] = []
    /// False until the first read of the store has arrived, so a view can
    /// tell "loading" from "empty".
    private(set) var loaded = false
    private(set) var syncStatus: CloudSync.Status = .off
    private(set) var syncEnabled: Bool
    /// Set when the store could not be opened or written; the app then runs
    /// on a store in memory and says so.
    private(set) var storeError: String?

    let database: AppDatabase
    /// False for tests, screenshots and the fixture: the toggle is then off
    /// and disabled, so it never disagrees with the status.
    let syncAllowed: Bool
    private var sync: CloudSync?
    private var streamTask: Task<Void, Never>?

    /// `fixture` puts sample items in a store in memory; `syncAllowed` false
    /// keeps iCloud out of it (tests, screenshots, the fixture).
    init(fixture: Bool, syncAllowed: Bool) {
        self.syncAllowed = syncAllowed && !fixture
        let defaults = UserDefaults.standard
        defaults.register(defaults: [AppIdentifiers.syncEnabledKey: true])
        syncEnabled = self.syncAllowed && defaults.bool(forKey: AppIdentifiers.syncEnabledKey)

        var openError: String?
        if fixture {
            database = Self.memoryStore()
            for item in Fixture.items { _ = try? database.save(item, now: item.createdAt) }
        } else {
            do {
                database = try AppDatabase(url: AppDatabase.url(appGroup: AppIdentifiers.appGroup))
            } catch {
                openError = error.localizedDescription
                database = Self.memoryStore()
            }
        }
        storeError = openError
    }

    /// Starts following the store and, when it is on, the sync.
    func start() {
        guard streamTask == nil else { return }
        let stream = database.itemsStream()
        streamTask = Task { [weak self] in
            do {
                for try await items in stream {
                    self?.items = items
                    self?.loaded = true
                }
            } catch {
                self?.storeError = error.localizedDescription
                self?.loaded = true
            }
        }
        if syncEnabled { startSync() }
    }

    // MARK: Edits

    @discardableResult
    func add(title: String, notes: String) -> Item? {
        let item = Item(title: title, notes: notes, createdAt: Date())
        return write { try $0.save(item) } != nil ? item : nil
    }

    func update(_ item: Item) {
        write { try $0.save(item) }
    }

    func delete(_ id: Item.ID) {
        write { try $0.deleteItem(id: id) }
    }

    func item(_ id: Item.ID?) -> Item? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    // MARK: Sync

    func setSyncEnabled(_ enabled: Bool) {
        guard syncAllowed else { return }
        syncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: AppIdentifiers.syncEnabledKey)
        if enabled {
            startSync()
        } else {
            let sync = sync
            self.sync = nil
            Task { await sync?.stop() }
            syncStatus = .off
        }
    }

    /// Pull to refresh, and the app coming to the foreground.
    func syncNow() async {
        await sync?.syncNow()
    }

    func sceneBecameActive() {
        AppDatabase.resume()
        Task { await syncNow() }
    }

    func sceneWentToBackground() {
        AppDatabase.suspend()
    }

    // MARK: Helpers

    private func startSync() {
        guard syncAllowed, sync == nil else { return }
        let sync = CloudSync(
            database: database,
            configuration: .init(containerID: AppIdentifiers.cloudContainer, zoneName: AppIdentifiers.syncZone),
            onStatus: { [weak self] status in
                Task { @MainActor in self?.syncStatusChanged(status) }
            },
            onApplied: { _ in
                Task { @MainActor in WidgetCenter.shared.reloadAllTimelines() }
            })
        self.sync = sync
        Task { await sync.start() }
    }

    private func syncStatusChanged(_ status: CloudSync.Status) {
        syncStatus = status
        if status == .deletedInICloud {
            // The sync stopped itself; the toggle shows it.
            sync = nil
            syncEnabled = false
            UserDefaults.standard.set(false, forKey: AppIdentifiers.syncEnabledKey)
        }
    }

    /// One local write: the store, then the sync and the widgets.
    @discardableResult
    private func write(_ change: (AppDatabase) throws -> String?) -> String? {
        do {
            guard let recordName = try change(database) else { return nil }
            let sync = sync
            Task { await sync?.push([recordName]) }
            WidgetCenter.shared.reloadAllTimelines()
            return recordName
        } catch {
            storeError = error.localizedDescription
            return nil
        }
    }

    private static func memoryStore() -> AppDatabase {
        do {
            return try AppDatabase.inMemory()
        } catch {
            fatalError("SQLite could not open a store in memory: \(error)")
        }
    }
}
