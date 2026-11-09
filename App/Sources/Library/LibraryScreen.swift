import SwiftUI
import AppText

/// The Library tab: the bundled manual (`docs/`), by section, and within a
/// long section by the index's groups, with search.
///
/// DEBUG `-DebugScreen` values for this tab:
/// - `article:<id>`: an article, such as `article:devices-and-sync/icloud-sync`.
/// - `search:<query>`: the index with a query typed.
/// - `info:<id>` (any tab): the article in a sheet, as an `InfoButton` on
///   another tab presents it.
struct LibraryScreen: View {
    @Environment(AppModel.self) private var model
    @State private var path: [ArticleID] = []
    @State private var query = ""
    @State private var appliedLaunch = false

    private let catalog = LibraryCatalog.bundled

    var body: some View {
        NavigationStack(path: $path) {
            index
                .navigationTitle(Copy.tab.library)
                .navigationDestination(for: ArticleID.self) { ArticleScreen(id: $0) }
        }
        .environment(\.articleNavigator, ArticleNavigator { path.append($0) })
        .onAppear(perform: applyLaunch)
    }

    private var index: some View {
        let sections = catalog.search(query)
        return List {
            ForEach(sections) { section in
                ForEach(section.groups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            NavigationLink(value: entry.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                    if !entry.summary.isEmpty {
                                        Text(entry.summary)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        // The section title on its first group; a group's own
                        // title under it.
                        VStack(alignment: .leading, spacing: 2) {
                            if group.id == section.groups.first?.id {
                                Text(section.title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                            if let title = group.title { Text(title) }
                        }
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: Copy.library.search.placeholder)
    }

    private func applyLaunch() {
        guard !appliedLaunch else { return }
        appliedLaunch = true
        #if DEBUG
        guard let screen = model.launch.screen, model.launch.tab == .library else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if screen.hasPrefix("article:") {
                path = [ArticleID(String(screen.dropFirst(8)))]
            } else if screen.hasPrefix("search:") {
                query = String(screen.dropFirst(7))
            }
        }
        #endif
    }
}
