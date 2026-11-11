import SwiftUI

/// Every build in the Release notes, newest first, opened from "See all"
/// under the Library's newest builds. A build pushes over this list on the
/// Library's own stack.
struct ReleaseNotesScreen: View {
    let section: LibraryCatalog.Section

    var body: some View {
        List {
            ForEach(section.entries) { entry in
                NavigationLink(value: LibraryRoute.article(entry.id)) {
                    IndexRow(entry: entry)
                }
            }
        }
        .navigationTitle(section.title)
    }
}
