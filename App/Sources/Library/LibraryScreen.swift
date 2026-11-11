import SwiftUI
import AppText

/// Where the Library's navigation stack goes.
enum LibraryRoute: Hashable {
    case article(ArticleID)
    /// Every build in the Release notes, from "See all".
    case releaseNotes
}

/// The Library tab: the bundled manual (`docs/`), by section, and within a
/// long section by the index's groups, with search.
///
/// The Release notes list their newest builds and "See all", which opens
/// every build on a screen of its own; a search lists every match.
///
/// DEBUG `-DebugScreen` values for this tab:
/// - `article:<id>`: an article, such as `article:devices-and-sync/icloud-sync`.
/// - `search:<query>`: the index with a query typed.
/// - `release-notes`: every build in the Release notes.
/// - `info:<id>` (any tab): the article in a sheet, as an `InfoButton` on
///   another tab presents it.
struct LibraryScreen: View {
    @Environment(AppModel.self) private var model
    @State private var path: [LibraryRoute] = []
    @State private var query = ""
    @State private var appliedLaunch = false

    private let catalog = LibraryCatalog.bundled

    var body: some View {
        NavigationStack(path: $path) {
            index
                .navigationTitle(Copy.tab.library)
                .navigationDestination(for: LibraryRoute.self) { route in
                    switch route {
                    case .article(let id): ArticleScreen(id: id)
                    case .releaseNotes: ReleaseNotesScreen(section: releaseNotes)
                    }
                }
        }
        .environment(\.articleNavigator, ArticleNavigator { path.append(.article($0)) })
        .onAppear(perform: applyLaunch)
    }

    /// The whole Release notes section, for "See all".
    private var releaseNotes: LibraryCatalog.Section {
        catalog.sections.first(where: \.isReleaseNotes)
            ?? LibraryCatalog.Section(folder: LibraryCatalog.Section.releaseNotesFolder, entries: [])
    }

    private var index: some View {
        let sections = catalog.search(query)
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return List {
            ForEach(sections) { section in
                // With nothing searched the Release notes show their newest
                // builds; a search shows every match.
                let shown = searching ? section : section.inIndex
                ForEach(shown.groups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            NavigationLink(value: LibraryRoute.article(entry.id)) {
                                IndexRow(entry: entry)
                            }
                        }
                        if group.id == shown.groups.last?.id, shown.entries.count < section.entries.count {
                            NavigationLink(value: LibraryRoute.releaseNotes) {
                                Text(Copy.library.releaseNotes.seeAll)
                            }
                        }
                    } header: {
                        // The section title on its first group; a group's own
                        // title under it.
                        VStack(alignment: .leading, spacing: 2) {
                            if group.id == shown.groups.first?.id {
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
                path = [.article(ArticleID(String(screen.dropFirst(8))))]
            } else if screen == "release-notes" {
                path = [.releaseNotes]
            } else if screen.hasPrefix("search:") {
                query = String(screen.dropFirst(7))
            }
        }
        #endif
    }
}

/// One article in the index or the Release notes list: its title and the
/// question it answers.
struct IndexRow: View {
    let entry: LibraryCatalog.Entry

    var body: some View {
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
