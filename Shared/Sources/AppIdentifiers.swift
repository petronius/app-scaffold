import Foundation

/// The identifiers every target shares. They must match `project.yml`
/// (entitlements, bundle ids) and the App IDs in the developer portal.
/// `Scripts/rename.sh` rewrites them for a new project.
enum AppIdentifiers {
    /// The App Group whose container holds the store, shared by an app and
    /// its widgets. The phone and the watch each have their own container
    /// under the same name; they meet through iCloud, never through the file.
    static let appGroup = "group.com.example.scaffold"

    /// The CloudKit container of the sync. Phone and watch use the same one.
    static let cloudContainer = "iCloud.com.example.scaffold"

    /// The custom zone in the private database. A shipped zone name is
    /// permanent: a new name is a new, empty zone.
    static let syncZone = "ScaffoldZone"

    /// The UserDefaults key of the sync toggle (Settings, iCloud).
    static let syncEnabledKey = "cloudSync.enabled"

    /// The widget's kind, which WidgetCenter reloads by.
    static let widgetKind = "ItemsWidget"
}
