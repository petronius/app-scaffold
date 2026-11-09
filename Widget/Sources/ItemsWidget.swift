import SwiftUI
import WidgetKit
import AppCore
import AppText

@main
struct ScaffoldWidgets: WidgetBundle {
    var body: some Widget {
        ItemsWidget()
    }
}

/// The home screen and Lock Screen widget: the count of items and the
/// newest titles.
struct ItemsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppIdentifiers.widgetKind, provider: ItemsProvider()) { entry in
            ItemsWidgetView(summary: entry.summary)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Copy.app.name)
        .description(Copy.widget.description)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct ItemsWidgetView: View {
    let summary: ItemsSummary
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(count)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(count).font(.headline).widgetAccentable()
                if let first = summary.latestTitles.first { Text(first).lineLimit(1) }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(count)
                    .font(.headline)
                    .monospacedDigit()
                    .widgetAccentable()
                ForEach(Array(summary.latestTitles.prefix(family == .systemSmall ? 2 : 3).enumerated()), id: \.offset) { _, title in
                    Text(title.isEmpty ? Copy.item.untitled : title)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var count: String {
        Format.count(summary.count, one: Copy.item.count.one, other: Copy.item.count.other(count:))
    }
}

#Preview(as: .systemSmall) {
    ItemsWidget()
} timeline: {
    ItemsEntry(date: .now, summary: ItemsSummary(count: 3, latestTitles: Fixture.items.map(\.title)))
}
