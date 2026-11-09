import Foundation
import Testing
@testable import Scaffold

/// The bundled Library against `spec/DOCS-STYLE.md`: every article is in the
/// index, every link between articles leads somewhere, and every
/// `ArticleID("…")` in the sources names a bundled file.
struct LibraryCatalogTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
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
        for entry in catalog.entries {
            #expect(linked.contains(entry.id), "\(entry.id) is linked from no other article's Related section")
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
