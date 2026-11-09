import SwiftUI
import AppText

/// One Library article: title, summary, sections, and the closing "In this
/// app", "Related" and "Sources" sections set apart.
struct ArticleScreen: View {
    let id: ArticleID

    @Environment(\.articleNavigator) private var navigator
    private let catalog = LibraryCatalog.bundled

    var body: some View {
        Group {
            if let entry = catalog.entry(id) {
                content(entry.article)
            } else {
                ContentUnavailableView(Copy.library.article.missing, systemImage: "doc.questionmark")
            }
        }
        // The title is the article's own heading, so the bar shows none.
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .environment(\.openURL, OpenURLAction { url in
            guard let target = LibraryInline.article(from: url) else { return .systemAction }
            navigator?.open(target)
            return .handled
        })
    }

    private func content(_ article: LibraryArticle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 8)
                if let summary = article.summary {
                    InlineText(summary, from: id).font(.body)
                }
                ForEach(Array(article.sections.enumerated()), id: \.offset) { _, section in
                    ArticleSectionView(section: section, source: id)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

/// One `##` section of an article.
private struct ArticleSectionView: View {
    let section: LibraryArticle.Section
    let source: ArticleID

    var body: some View {
        switch section.kind {
        case .standard:
            VStack(alignment: .leading, spacing: 10) {
                if let heading = section.heading {
                    Text(heading)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 4)
                }
                blocks(style: .callout)
            }
        case .inThisApp:
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: section.heading ?? "")
                blocks(style: .subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        case .related:
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: section.heading ?? "")
                    .padding(.bottom, 2)
                ForEach(Array(relatedLinks.enumerated()), id: \.offset) { _, link in
                    RelatedRow(link: link, source: source)
                }
            }
        case .sources:
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: section.heading ?? "")
                blocks(style: .footnote, secondary: true)
            }
        }
    }

    private var relatedLinks: [RelatedLink] {
        section.blocks.flatMap { block -> [RelatedLink] in
            guard case .list(_, let items) = block else { return [] }
            return items.compactMap(RelatedLink.init(item:))
        }
    }

    private func blocks(style: Font.TextStyle, secondary: Bool = false) -> some View {
        ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
            LibraryBlockView(block: block, source: source, style: style, secondary: secondary)
        }
    }
}

/// The heading of a closing section, in the system's own section style.
private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A line of the Related section: the article's name as a link, and why to
/// read it.
private struct RelatedRow: View {
    let link: RelatedLink
    let source: ArticleID

    @Environment(\.articleNavigator) private var navigator

    var body: some View {
        let target = ArticleID(link: link.target, from: source)
            .flatMap { LibraryCatalog.bundled.entry($0) != nil ? $0 : nil }
        Button {
            if let target { navigator?.open(target) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(target == nil ? Color.primary : Palette.accent)
                    if !link.reason.isEmpty {
                        Text(link.reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if target != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
    }
}

/// Inline Markdown (links, emphasis) as one `Text`, links between articles
/// resolved to the Library's own scheme.
struct InlineText: View {
    private let attributed: AttributedString

    init(_ markdown: String, from source: ArticleID) {
        let resolved = LibraryInline.resolvingLinks(markdown, from: source, known: LibraryCatalog.bundled.ids)
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        attributed = (try? AttributedString(markdown: resolved, options: options)) ?? AttributedString(resolved)
    }

    var body: some View {
        Text(attributed)
            .fixedSize(horizontal: false, vertical: true)
    }
}
