import Foundation

/// The bundled Library: every article under `docs/`, in the order and
/// sections the index (`docs/README.md`) gives them.
///
/// Nothing here names an article. The index orders the list and supplies
/// each article's one-line description and, where a section is long, the
/// `###` group it is listed under; the article's own `#` heading is its
/// title; its folder is its section.
struct LibraryCatalog {
    struct Entry: Identifiable, Equatable {
        var id: ArticleID
        var title: String
        /// The index line's description: what question the article answers.
        var summary: String
        /// The index's `###` heading the article is listed under, or nil in
        /// a section without groups.
        var group: String?
        var article: LibraryArticle
        /// Lower-cased, diacritics folded, for search.
        var searchText: String
    }

    struct Section: Identifiable, Equatable {
        /// The folder under `docs/`.
        var folder: String
        var entries: [Entry]
        var id: String { folder }

        /// The section `Scripts/release-notes.sh` writes: one article per
        /// TestFlight build, which the index lists newest first.
        static let releaseNotesFolder = "release-notes"
        /// How many builds the Library shows before "See all".
        static let releaseNotesInIndex = 3

        var isReleaseNotes: Bool { folder == Self.releaseNotesFolder }

        /// The section as the Library lists it with nothing searched: the
        /// newest builds of the Release notes, any other section whole.
        /// "See all" opens the whole Release notes.
        var inIndex: Section {
            guard isReleaseNotes else { return self }
            return Section(folder: folder, entries: Array(entries.prefix(Self.releaseNotesInIndex)))
        }

        /// The folder name read as a heading in sentence case:
        /// `devices-and-sync` reads "Devices and sync".
        var title: String {
            let words = folder.replacingOccurrences(of: "-", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }

        /// The entries by group, in the order the groups first appear. A
        /// section without groups is one group with no title.
        var groups: [Group] {
            var groups: [Group] = []
            for entry in entries {
                if let i = groups.firstIndex(where: { $0.title == entry.group }) {
                    groups[i].entries.append(entry)
                } else {
                    groups.append(Group(title: entry.group, entries: [entry]))
                }
            }
            return groups
        }
    }

    /// A run of articles under one of the index's `###` headings.
    struct Group: Identifiable, Equatable {
        var title: String?
        var entries: [Entry]
        var id: String { title ?? "" }
    }

    let sections: [Section]

    var entries: [Entry] { sections.flatMap(\.entries) }
    var ids: Set<ArticleID> { Set(entries.map(\.id)) }

    func entry(_ id: ArticleID) -> Entry? { entries.first { $0.id == id } }

    /// The catalog of the app's own bundle, read once.
    static let bundled = LibraryCatalog(bundle: .main)

    init(bundle: Bundle) {
        guard let root = bundle.resourceURL?.appendingPathComponent("docs", isDirectory: true) else {
            self.init(index: "", articles: [:])
            return
        }
        self.init(docsDirectory: root)
    }

    /// Reads `README.md` and every `<section>/<article>.md` in a directory.
    init(docsDirectory root: URL) {
        let fileManager = FileManager.default
        let index = (try? String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)) ?? ""
        var articles: [ArticleID: String] = [:]
        let folders = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for folder in folders where (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let files = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "md" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let id = ArticleID(folder.lastPathComponent + "/" + file.deletingPathExtension().lastPathComponent)
                articles[id] = text
            }
        }
        self.init(index: index, articles: articles)
    }

    /// The catalog from the index text and the articles' Markdown, keyed by
    /// identifier. Articles the index lists come first, in its order; any it
    /// misses follow in their folders, by title.
    init(index: String, articles: [ArticleID: String]) {
        var listed: [(id: ArticleID, summary: String, group: String?)] = []
        var group: String?
        for block in LibraryMarkdown.parse(index) {
            switch block {
            case .heading(2, _): group = nil
            case .heading(3, let text): group = text
            case .list(_, let items):
                for item in items {
                    guard let link = RelatedLink(item: item),
                          let id = ArticleID(link: link.target, from: nil),
                          articles[id] != nil, !listed.contains(where: { $0.id == id }) else { continue }
                    listed.append((id, link.reason, group))
                }
            default: break
            }
        }
        let unlisted = articles.keys.filter { id in !listed.contains { $0.id == id } }
        var entries: [Entry] = listed.map {
            Self.entry($0.id, summary: $0.summary, group: $0.group, markdown: articles[$0.id]!)
        }
        entries += unlisted.map { Self.entry($0, summary: "", group: nil, markdown: articles[$0]!) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        var sections: [Section] = []
        for entry in entries {
            let folder = entry.id.folder ?? ""
            if let i = sections.firstIndex(where: { $0.folder == folder }) {
                sections[i].entries.append(entry)
            } else {
                sections.append(Section(folder: folder, entries: [entry]))
            }
        }
        self.sections = sections
    }

    private static func entry(_ id: ArticleID, summary: String, group: String?, markdown: String) -> Entry {
        let fallback = id.path.split(separator: "/").last.map { $0.replacingOccurrences(of: "-", with: " ") } ?? id.path
        let article = LibraryArticle(markdown: markdown, fallbackTitle: fallback)
        return Entry(id: id, title: article.title, summary: LibraryInline.plain(summary), group: group, article: article,
                     searchText: fold(article.searchText + " " + summary))
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// The sections holding the articles that match every word of a query,
    /// in index order, with the articles whose title matches first in each
    /// group. An empty query matches everything.
    func search(_ query: String) -> [Section] {
        let words = Self.fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return sections }
        return sections.compactMap { section in
            let ranked = section.groups.flatMap { group in
                let matches = group.entries.filter { entry in words.allSatisfy { entry.searchText.contains($0) } }
                let inTitle = matches.filter { entry in words.allSatisfy { Self.fold(entry.title).contains($0) } }
                return inTitle + matches.filter { entry in !inTitle.contains { $0.id == entry.id } }
            }
            return ranked.isEmpty ? nil : Section(folder: section.folder, entries: ranked)
        }
    }
}
