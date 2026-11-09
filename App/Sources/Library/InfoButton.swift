import SwiftUI
import AppText

/// Opens an article inside the navigation stack a view sits in. The Library
/// tab and the article sheet each set one; elsewhere it is nil, and an
/// `InfoButton` presents the article in a sheet of its own.
struct ArticleNavigator {
    var open: (ArticleID) -> Void
}

extension EnvironmentValues {
    @Entry var articleNavigator: ArticleNavigator? = nil
}

/// The small "i" placed after a value or a setting: it opens the article
/// that explains it. In the Library tab it pushes the article; on any other
/// screen it presents the article in a sheet.
///
///     LabeledContent(Copy.sync.status.label) {
///         Text(store.syncStatus.text)
///         InfoButton(article: .iCloudSync)
///     }
struct InfoButton: View {
    let article: ArticleID

    @Environment(\.articleNavigator) private var navigator
    @State private var presented: ArticleID?

    var body: some View {
        Button {
            if let navigator { navigator.open(article) } else { presented = article }
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(Palette.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.library.info.label(title: LibraryCatalog.bundled.entry(article)?.title ?? article.path))
        .sheet(item: $presented) { ArticleSheet(article: $0) }
    }
}

/// An article presented over another tab: its own navigation stack, so
/// links inside it push within the sheet, and Done to close it.
struct ArticleSheet: View {
    let article: ArticleID

    @Environment(\.dismiss) private var dismiss
    @State private var path: [ArticleID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ArticleScreen(id: article)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Copy.action.done) { dismiss() }
                    }
                }
                .navigationDestination(for: ArticleID.self) { ArticleScreen(id: $0) }
        }
        .environment(\.articleNavigator, ArticleNavigator { path.append($0) })
    }
}

extension View {
    /// DEBUG: `-DebugScreen info:<article>` presents that article in a sheet
    /// over the launch tab, the way an `InfoButton` on another tab does.
    func debugArticleSheet(_ launch: LaunchOptions) -> some View {
        modifier(DebugArticleSheet(screen: launch.screen))
    }
}

private struct DebugArticleSheet: ViewModifier {
    let screen: String?
    @State private var presented: ArticleID?

    func body(content: Content) -> some View {
        content
            .sheet(item: $presented) { ArticleSheet(article: $0) }
            .onAppear {
                #if DEBUG
                if let screen, screen.hasPrefix("info:") {
                    presented = ArticleID(String(screen.dropFirst(5)))
                }
                #endif
            }
    }
}
