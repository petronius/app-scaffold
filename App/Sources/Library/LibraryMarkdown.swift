import Foundation

/// One block of a Library article. Inline Markdown (links, emphasis) stays
/// in the text for the renderer; this type only carries the structure.
enum LibraryBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    /// Consecutive list items, as one list.
    case list(ordered: Bool, items: [String])
    case table(header: [String], rows: [[String]])
    /// A fenced block whose language is `equation`.
    case equation(Equation)
    /// A fenced block with no language (or any other): a monospaced diagram.
    case diagram(String)
}

/// A formula and the variables it uses, as `spec/DOCS-STYLE.md` writes it:
/// the formula lines, a blank line, then one `name: meaning` per line.
struct Equation: Equatable {
    struct Variable: Equatable {
        var name: String
        var meaning: String
    }
    var formula: [String]
    var variables: [Variable]

    init(formula: [String], variables: [Variable]) {
        self.formula = formula
        self.variables = variables
    }

    init(code: String) {
        var formula: [String] = []
        var variables: [Variable] = []
        var inVariables = false
        for line in code.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !formula.isEmpty { inVariables = true }
                continue
            }
            if !inVariables {
                formula.append(trimmed)
            } else if let colon = trimmed.range(of: ": ") {
                variables.append(Variable(name: String(trimmed[..<colon.lowerBound]),
                                          meaning: String(trimmed[colon.upperBound...])))
            } else if !variables.isEmpty {
                variables[variables.count - 1].meaning += " " + trimmed
            } else {
                variables.append(Variable(name: trimmed, meaning: ""))
            }
        }
        self.init(formula: formula, variables: variables)
    }
}

/// An article split into the shape `spec/DOCS-STYLE.md` gives every article:
/// a title, a summary paragraph, sections, and the closing "In this app",
/// "Related" and "Sources" sections, which the viewer sets apart.
struct LibraryArticle: Equatable {
    struct Section: Equatable {
        enum Kind: Equatable {
            case standard
            case inThisApp
            case related
            case sources
        }
        /// The `##` heading, or nil for the blocks between the summary and
        /// the first heading.
        var heading: String?
        var kind: Kind
        var blocks: [LibraryBlock]
    }

    var title: String
    var summary: String?
    var sections: [Section]

    /// The closing sections, matched on their heading as DOCS-STYLE names
    /// them.
    static func kind(ofHeading heading: String) -> Section.Kind {
        switch heading.lowercased() {
        case "in this app": .inThisApp
        case "related": .related
        case "sources": .sources
        default: .standard
        }
    }

    init(title: String, summary: String?, sections: [Section]) {
        self.title = title
        self.summary = summary
        self.sections = sections
    }

    init(markdown: String, fallbackTitle: String) {
        let blocks = LibraryMarkdown.parse(markdown)
        var title: String?
        var summary: String?
        var sections: [Section] = []
        var current = Section(heading: nil, kind: .standard, blocks: [])
        for block in blocks {
            switch block {
            case .heading(1, let text) where title == nil:
                title = text
            case .paragraph(let text) where title != nil && summary == nil && sections.isEmpty && current.blocks.isEmpty:
                summary = text
            case .heading(2, let text):
                if current.heading != nil || !current.blocks.isEmpty { sections.append(current) }
                current = Section(heading: text, kind: Self.kind(ofHeading: text), blocks: [])
            default:
                current.blocks.append(block)
            }
        }
        if current.heading != nil || !current.blocks.isEmpty { sections.append(current) }
        self.init(title: title ?? fallbackTitle, summary: summary, sections: sections)
    }

    /// The article as plain words, for search.
    var searchText: String {
        var parts = [title, summary ?? ""]
        for section in sections {
            parts.append(section.heading ?? "")
            for block in section.blocks {
                switch block {
                case .heading(_, let text), .paragraph(let text): parts.append(text)
                case .list(_, let items): parts += items
                case .table(let header, let rows): parts += header + rows.flatMap { $0 }
                case .equation(let equation): parts += equation.variables.map(\.meaning)
                case .diagram: break
                }
            }
        }
        return LibraryInline.plain(parts.joined(separator: " "))
    }
}

/// A line of the Related section: `[Title](target.md): why to read it`.
struct RelatedLink: Equatable {
    var title: String
    var target: String
    var reason: String

    init(title: String, target: String, reason: String) {
        self.title = title
        self.target = target
        self.reason = reason
    }

    /// Nil when the item does not start with a link.
    init?(item: String) {
        guard let link = LibraryInline.leadingLink(item) else { return nil }
        var rest = link.rest.trimmingCharacters(in: .whitespaces)
        for separator in [":", ","] where rest.hasPrefix(separator) {
            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        self.init(title: link.text, target: link.target, reason: rest)
    }
}

/// Inline helpers: links and plain text.
enum LibraryInline {
    /// The URL scheme a resolved link between articles carries. The viewer
    /// intercepts it; nothing outside the app sees it.
    static let scheme = "scaffold-library"

    static func url(for article: ArticleID) -> URL? {
        URL(string: scheme + ":" + article.path)
    }

    static func article(from url: URL) -> ArticleID? {
        guard url.scheme == scheme else { return nil }
        let path = url.absoluteString.dropFirst(scheme.count + 1)
        return path.isEmpty ? nil : ArticleID(String(path))
    }

    /// `text` with each link to another article rewritten to the library
    /// scheme. A link to an article that is not bundled keeps its words and
    /// loses the link, so a reader never taps a dead link. Links with a
    /// scheme of their own pass through.
    static func resolvingLinks(_ text: String, from source: ArticleID?, known: Set<ArticleID>) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "[") {
            out += rest[..<open]
            rest = rest[open...]
            guard let link = link(at: rest) else {
                out.append(rest.removeFirst())
                continue
            }
            if let target = ArticleID(link: link.target, from: source) {
                if known.contains(target), let url = url(for: target) {
                    out += "[\(link.text)](\(url.absoluteString))"
                } else {
                    out += link.text
                }
            } else {
                out += rest[..<link.end]
            }
            rest = rest[link.end...]
        }
        return out + rest
    }

    /// A `[text](target)` at the start of `text`, and what follows it.
    static func leadingLink(_ text: String) -> (text: String, target: String, rest: String)? {
        let trimmed = Substring(text.trimmingCharacters(in: .whitespaces))
        guard trimmed.first == "[", let link = link(at: trimmed) else { return nil }
        return (link.text, link.target, String(trimmed[link.end...]))
    }

    private static func link(at text: Substring) -> (text: String, target: String, end: Substring.Index)? {
        guard text.first == "[", let close = text.firstIndex(of: "]") else { return nil }
        let paren = text.index(after: close)
        guard paren < text.endIndex, text[paren] == "(",
              let end = text[paren...].firstIndex(of: ")") else { return nil }
        return (String(text[text.index(after: text.startIndex)..<close]),
                String(text[text.index(after: paren)..<end]),
                text.index(after: end))
    }

    /// Inline Markdown reduced to its words: links to their text, emphasis
    /// markers dropped.
    static func plain(_ text: String) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "[") {
            out += rest[..<open]
            rest = rest[open...]
            if let link = link(at: rest) {
                out += link.text
                rest = rest[link.end...]
            } else {
                out.append(rest.removeFirst())
            }
        }
        out += rest
        for marker in ["**", "__", "`", "*", "_"] {
            out = out.replacingOccurrences(of: marker, with: "")
        }
        return out
    }
}

/// A line-based parser for the Markdown the Library uses: headings,
/// paragraphs, bullet and numbered lists, tables, and fenced blocks
/// (`equation`, and diagrams). Foundation only and
/// deterministic, so the tests run it without a view.
enum LibraryMarkdown {
    static func parse(_ markdown: String) -> [LibraryBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [LibraryBlock] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var listOrdered = false

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        func flushList() {
            if !listItems.isEmpty { blocks.append(.list(ordered: listOrdered, items: listItems)) }
            listItems = []
        }
        func flush() { flushParagraph(); flushList() }

        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                flush()
                let fence = String(line.prefix(3))
                let info = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    body.append(lines[i])
                    i += 1
                }
                i += 1
                blocks.append(fenced(info: info, body: body))
                continue
            }
            if line.isEmpty {
                flush()
                i += 1
                continue
            }
            if let heading = heading(line) {
                flush()
                blocks.append(heading)
                i += 1
                continue
            }
            if line.contains("|"), i + 1 < lines.count, isDelimiterRow(lines[i + 1]) {
                flush()
                let header = cells(line)
                var rows: [[String]] = []
                i += 2
                while i < lines.count {
                    let row = lines[i].trimmingCharacters(in: .whitespaces)
                    guard !row.isEmpty, row.contains("|") else { break }
                    var cells = cells(row)
                    if cells.count < header.count { cells += Array(repeating: "", count: header.count - cells.count) }
                    rows.append(Array(cells.prefix(header.count)))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }
            if let item = listItem(line) {
                flushParagraph()
                if !listItems.isEmpty && listOrdered != item.ordered { flushList() }
                listOrdered = item.ordered
                listItems.append(item.text)
                i += 1
                continue
            }
            if !listItems.isEmpty, raw.first == " " || raw.first == "\t" {
                listItems[listItems.count - 1] += " " + line
                i += 1
                continue
            }
            flushList()
            paragraph.append(line)
            i += 1
        }
        flush()
        return blocks
    }

    private static func fenced(info: String, body: [String]) -> LibraryBlock {
        let words = info.split(separator: " ").map(String.init)
        switch words.first {
        case "equation":
            return .equation(Equation(code: body.joined(separator: "\n")))
        default:
            var lines = body
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
            return .diagram(lines.joined(separator: "\n"))
        }
    }

    private static func heading(_ line: String) -> LibraryBlock? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " else { return nil }
        return .heading(level: level, text: rest.trimmingCharacters(in: .whitespaces))
    }

    private static func listItem(_ line: String) -> (ordered: Bool, text: String)? {
        for bullet in ["- ", "* ", "+ "] where line.hasPrefix(bullet) {
            return (false, String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
        }
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return (true, rest.dropFirst(2).trimmingCharacters(in: .whitespaces))
    }

    private static func isDelimiterRow(_ raw: String) -> Bool {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard line.contains("|"), line.contains("-") else { return false }
        return cells(line).allSatisfy { cell in
            var body = Substring(cell)
            if body.hasPrefix(":") { body = body.dropFirst() }
            if body.hasSuffix(":") { body = body.dropLast() }
            return !body.isEmpty && body.allSatisfy { $0 == "-" }
        }
    }

    private static func cells(_ line: String) -> [String] {
        var parts = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.first == "" { parts.removeFirst() }
        if parts.last == "" { parts.removeLast() }
        return parts
    }
}
