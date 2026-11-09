import Foundation
import GRDB
import AppCore

/// The local store: SQLite through GRDB, the source of truth on this device.
///
/// The app opens it read-write in the App Group container; the widgets open
/// the same file read-only. Every synced table has the same four columns
/// beside its own: `id` (the record key), `payload` (the model as
/// `SyncCoding` JSON), `updatedAt` (the edit stamp, a `SyncStamp`) and
/// `deletedAt` (set on delete: the row stays as a tombstone so the deletion
/// syncs). Domain models persist as their JSON payload plus the denormalised
/// columns a query needs, so a field added to a model needs no migration.
///
/// Schema changes go through `migrator`, one named migration per change,
/// never an edit to a shipped one.
public final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    /// Opens (and on first use creates and migrates) the store at `url`.
    /// `readOnly` is for the widgets: no migration, and a store the app has
    /// not created yet is an error the caller shows as an empty state.
    public init(url: URL, readOnly: Bool = false) throws {
        var configuration = Configuration()
        configuration.readonly = readOnly
        // The app and its widgets share the file across processes.
        configuration.busyMode = .timeout(5)
        // A suspended app must not hold a lock on a file in a shared
        // container, or the system kills it (0xdead10cc). The app posts
        // `suspend()` when it leaves the foreground.
        configuration.observesSuspensionNotifications = true
        if !readOnly {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let pool = try DatabasePool(path: url.path, configuration: configuration)
        writer = pool
        if !readOnly { try Self.migrator.migrate(pool) }
    }

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// A store that lives in memory only: tests, previews and the DEBUG
    /// fixture, so they never touch the user's data.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(writer: DatabaseQueue())
    }

    /// The store's file in the App Group container, or in the app's own
    /// Application Support folder where the group is not available.
    public static func url(appGroup: String) -> URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
            ?? URL.applicationSupportDirectory
        return base.appending(path: "Store.sqlite")
    }

    /// Release file locks before the app is suspended.
    public static func suspend() {
        NotificationCenter.default.post(name: Database.suspendNotification, object: nil)
    }

    /// Allow access again once the app is back in the foreground.
    public static func resume() {
        NotificationCenter.default.post(name: Database.resumeNotification, object: nil)
    }

    // MARK: - Schema

    static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // A changed migration in a DEBUG build recreates the store rather
        // than failing on a mismatch. Release builds never erase.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1-item") { db in
            try db.execute(sql: """
                CREATE TABLE item (
                    id TEXT PRIMARY KEY NOT NULL,
                    payload BLOB NOT NULL,
                    title TEXT NOT NULL,
                    createdAt DOUBLE NOT NULL,
                    updatedAt INTEGER NOT NULL,
                    deletedAt INTEGER
                );
                CREATE INDEX item_live ON item(deletedAt, createdAt);
                """)
        }

        migrator.registerMigration("v1-sync") { db in
            // Per record: the stamp this device last pushed or applied, and
            // CloudKit's archived system fields as last seen, so a save
            // presents the right change tag.
            try db.execute(sql: """
                CREATE TABLE syncMeta (
                    recordName TEXT PRIMARY KEY NOT NULL,
                    recordType TEXT NOT NULL,
                    pushedAt INTEGER,
                    systemFields BLOB
                );
                CREATE TABLE syncState (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    deviceID TEXT NOT NULL,
                    engineState BLOB
                );
                """)
        }
        return migrator
    }()
}

// MARK: - Edit stamps

extension AppDatabase {
    /// The stamp for an edit made `now` to a row last stamped `previous`:
    /// never earlier than the previous one, so a device clock that moved
    /// back cannot make a newer edit lose.
    static func stamp(_ now: Date, after previous: SyncStamp?) -> SyncStamp {
        let stamp = SyncStamp(date: now)
        guard let previous else { return stamp }
        return max(stamp, previous + 1)
    }
}
