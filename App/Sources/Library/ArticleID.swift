import Foundation

/// A Library article, named by its path under `docs/` without the `.md`
/// extension: `ArticleID("devices-and-sync/icloud-sync")` is
/// `docs/devices-and-sync/icloud-sync.md`.
///
/// Other screens link a value to its article with
/// `InfoButton(article: .iCloudSync)`. A unit that writes an article adds its
/// identifier in an extension in its own files:
///
///     extension ArticleID {
///         static let iCloudSync = ArticleID("devices-and-sync/icloud-sync")
///     }
///
/// `ArticleIDTests` scans the app's sources for every `ArticleID("…")` and
/// fails when one names a file the Library does not bundle.
struct ArticleID: Hashable, Sendable, Identifiable, CustomStringConvertible {
    /// The path under `docs/`, without the extension.
    let path: String

    init(_ path: String) { self.path = path }

    var id: String { path }
    var description: String { path }

    /// The section folder the article sits in (`devices-and-sync`), or nil for a file at
    /// the root of `docs/`.
    var folder: String? {
        let parts = path.split(separator: "/")
        return parts.count > 1 ? String(parts[0]) : nil
    }

    /// The article a Markdown link points at, resolved against the folder of
    /// the article that holds the link: `apple-watch.md` from
    /// `devices-and-sync/icloud-sync`, `../using-the-app/items.md` across
    /// sections, `using-the-app/items.md` from the index. Nil for a
    /// target that is not a relative `.md` path.
    init?(link target: String, from source: ArticleID?) {
        let head = String(target.split(separator: "#", omittingEmptySubsequences: false).first ?? "")
        guard head.hasSuffix(".md"), URL(string: head)?.scheme == nil else { return nil }
        var parts = (source?.folder).map { [$0] } ?? []
        if head.hasPrefix("/") { parts = [] }
        for component in head.dropLast(3).split(separator: "/").map(String.init) {
            switch component {
            case ".", "": continue
            case "..": if !parts.isEmpty { parts.removeLast() }
            default: parts.append(component)
            }
        }
        guard !parts.isEmpty else { return nil }
        self.init(parts.joined(separator: "/"))
    }
}

extension ArticleID {
    static let items = ArticleID("using-the-app/items")
    static let iCloudSync = ArticleID("devices-and-sync/icloud-sync")
    static let appleWatch = ArticleID("devices-and-sync/apple-watch")
}
