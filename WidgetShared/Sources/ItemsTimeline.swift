import WidgetKit
import AppCore
import AppData

/// The timeline both widget extensions share: the home screen widget on the
/// phone and the complication on the watch. Each reads its own device's
/// store, read-only, from the App Group container. The app reloads the
/// timelines after every write and every applied sync, so the widget never
/// polls.
struct ItemsEntry: TimelineEntry {
    var date: Date
    var summary: ItemsSummary
}

struct ItemsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ItemsEntry {
        ItemsEntry(date: Date(), summary: ItemsSummary(count: 3, latestTitles: Fixture.items.map(\.title)))
    }

    func getSnapshot(in context: Context, completion: @escaping (ItemsEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : ItemsEntry(date: Date(), summary: Self.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ItemsEntry>) -> Void) {
        completion(Timeline(entries: [ItemsEntry(date: Date(), summary: Self.read())], policy: .never))
    }

    /// The store's summary, or empty where the app has not created the store
    /// yet.
    static func read() -> ItemsSummary {
        let url = AppDatabase.url(appGroup: AppIdentifiers.appGroup)
        guard FileManager.default.fileExists(atPath: url.path),
              let database = try? AppDatabase(url: url, readOnly: true),
              let summary = try? database.summary() else { return .empty }
        return summary
    }
}
