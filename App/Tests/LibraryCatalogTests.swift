import Foundation
import Testing
@testable import Scaffold

/// The bundled Library against `spec/DOCS-STYLE.md`: every article is in the
/// index, every link between articles leads somewhere, and every
/// `ArticleID("…")` in the sources names a bundled file.
struct LibraryCatalogTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// The section `Scripts/release-notes.sh` writes, one article per
    /// TestFlight build, reached from the index alone.
    static let releaseNotes = LibraryCatalog.Section.releaseNotesFolder
    let catalog = LibraryCatalog(docsDirectory: root.appending(path: "docs"))

    @Test func theAppBundlesTheLibrary() {
        #expect(!LibraryCatalog.bundled.entries.isEmpty)
        #expect(LibraryCatalog.bundled.ids == catalog.ids)
    }

    @Test func everyArticleIsInTheIndexWithASummary() {
        for entry in catalog.entries {
            #expect(!entry.summary.isEmpty, "\(entry.id) is missing from docs/README.md")
            #expect(entry.article.summary != nil, "\(entry.id) has no summary paragraph")
        }
    }

    /// With nothing searched the Library shows the newest three builds of
    /// the Release notes, then "See all"; every other section whole.
    @Test func theIndexShowsTheNewestReleaseNotes() {
        for section in catalog.sections {
            if section.isReleaseNotes {
                let builds = section.entries.map(\.id.path)
                #expect(builds == builds.sorted(by: >), "the index lists the builds newest first")
                #expect(section.inIndex.entries.map(\.id) == Array(section.entries.prefix(3)).map(\.id))
            } else {
                #expect(section.inIndex == section, "\(section.folder) is cut in the index")
            }
        }
    }

    @Test func theIndexCutsReleaseNotesToThree() {
        let builds = ["build-5", "build-4", "build-3", "build-2", "build-1"]
        let index = "## Release notes\n\n" + builds.map { "- [\($0)](release-notes/\($0).md): Uploaded" }.joined(separator: "\n")
        let articles = Dictionary(uniqueKeysWithValues: builds.map {
            (ArticleID("release-notes/\($0)"), "# \($0)\n\nVersion 0.1.0.\n")
        })
        let section = LibraryCatalog(index: index, articles: articles).sections.first
        #expect(section?.entries.count == 5)
        #expect(section?.inIndex.entries.map(\.id.path)
                == ["release-notes/build-5", "release-notes/build-4", "release-notes/build-3"])
    }

    @Test func everyLinkBetweenArticlesResolves() {
        for entry in catalog.entries {
            for target in Self.links(in: entry.article) {
                guard let id = ArticleID(link: target, from: entry.id) else { continue }
                #expect(catalog.ids.contains(id), "\(entry.id) links to \(target), which is not bundled")
            }
        }
    }

    @Test func everyArticleIsLinkedFromAnother() {
        let linked = Set(catalog.entries.flatMap { entry in
            Self.links(in: entry.article).compactMap { ArticleID(link: $0, from: entry.id) }.filter { $0 != entry.id }
        })
        for entry in catalog.entries where entry.id.folder != Self.releaseNotes {
            #expect(linked.contains(entry.id), "\(entry.id) is linked from no other article's Related section")
        }
    }

    /// A build's release notes hold New features, Fixes and Other changes,
    /// or some of them, and nothing else (`spec/DOCS-STYLE.md`, "Release notes").
    @Test func releaseNotesHoldOnlyTheirLists() {
        for entry in catalog.entries where entry.id.folder == Self.releaseNotes {
            let headings = entry.article.sections.map(\.heading)
            #expect(!headings.isEmpty, "\(entry.id) holds no notes")
            for heading in headings {
                #expect(["New features", "Fixes", "Other changes"].contains(heading ?? ""), "\(entry.id) has a section \(heading ?? "without a heading")")
            }
        }
    }

    @Test func everyArticleIDInTheSourcesIsBundled() throws {
        let sources = Self.root.appending(path: "App/Sources")
        let pattern = try Regex(#"ArticleID\("([^"]+)"\)"#)
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let file = files?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in text.matches(of: pattern) {
                guard let path = match.output[1].substring.map(String.init), path.contains("/") else { continue }
                #expect(catalog.ids.contains(ArticleID(path)), "\(file.lastPathComponent) names \(path), which is not bundled")
            }
        }
    }

    @Test func linksBetweenArticlesResolveAgainstTheirFolder() {
        let source = ArticleID("devices-and-sync/icloud-sync")
        #expect(ArticleID(link: "apple-watch.md", from: source) == ArticleID("devices-and-sync/apple-watch"))
        #expect(ArticleID(link: "../using-the-app/items.md", from: source) == ArticleID("using-the-app/items"))
        #expect(ArticleID(link: "using-the-app/items.md", from: nil) == ArticleID("using-the-app/items"))
        #expect(ArticleID(link: "https://www.apple.com", from: source) == nil)
    }

    @Test func theParserReadsTheArticleShape() {
        let article = LibraryArticle(markdown: """
            # Title

            The summary.

            ## How it works

            - one
            - two

            | A | B |
            |---|---|
            | 1 | 2 |

            ```equation
            a = b + c

            a: the sum
            ```

            ## Related

            - [Other](other.md): why to read it
            """, fallbackTitle: "x")
        #expect(article.title == "Title")
        #expect(article.summary == "The summary.")
        #expect(article.sections.map(\.kind) == [.standard, .related])
        #expect(article.sections[0].blocks == [
            .list(ordered: false, items: ["one", "two"]),
            .table(header: ["A", "B"], rows: [["1", "2"]]),
            .equation(Equation(formula: ["a = b + c"], variables: [.init(name: "a", meaning: "the sum")])),
        ])
    }

    static func links(in article: LibraryArticle) -> [String] {
        var texts = [article.summary ?? ""]
        for section in article.sections {
            for block in section.blocks {
                switch block {
                case .paragraph(let text), .heading(_, let text): texts.append(text)
                case .list(_, let items): texts += items
                case .table(let header, let rows): texts += header + rows.flatMap { $0 }
                default: break
                }
            }
        }
        let pattern = /\]\(([^)]+)\)/
        return texts.flatMap { $0.matches(of: pattern).map { String($0.output.1) } }
    }
}
