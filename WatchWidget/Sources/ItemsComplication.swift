import SwiftUI
import WidgetKit
import AppCore
import AppText

@main
struct ScaffoldComplications: WidgetBundle {
    var body: some Widget {
        ItemsComplication()
    }
}

/// The watch complication: the count of items on this watch. A complication
/// is a screen: the count appears once, with nothing that repeats it.
struct ItemsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppIdentifiers.widgetKind, provider: ItemsProvider()) { entry in
            ItemsComplicationView(summary: entry.summary)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Copy.app.name)
        .description(Copy.widget.description)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct ItemsComplicationView: View {
    let summary: ItemsSummary
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "checklist").font(.caption2).widgetAccentable()
                    Text(Format.grouped(Double(summary.count))).font(.title3.weight(.semibold)).monospacedDigit()
                }
            }
        case .accessoryCorner:
            Text(Format.grouped(Double(summary.count)))
                .monospacedDigit()
                .widgetCurvesContent()
                .widgetLabel { Text(Copy.app.name) }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(count).font(.headline).widgetAccentable()
                if let first = summary.latestTitles.first { Text(first).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(count)
        }
    }

    private var count: String {
        Format.count(summary.count, one: Copy.item.count.one, other: Copy.item.count.other(count:))
    }
}
