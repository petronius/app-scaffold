import SwiftUI

/// One block of an article: paragraph, list, table, equation or diagram.
/// Headings of level 3 and below are set here; `##` headings open sections
/// (`ArticleSectionView`).
struct LibraryBlockView: View {
    let block: LibraryBlock
    let source: ArticleID
    /// The text style of running text in the section the block sits in.
    let style: Font.TextStyle
    var secondary = false

    var body: some View {
        switch block {
        case .heading(_, let text):
            Text(text)
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 2)
        case .paragraph(let text):
            InlineText(text, from: source)
                .font(.system(style))
                .foregroundStyle(secondary ? .secondary : .primary)
                .lineSpacing(2)
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(ordered ? "\(i + 1)." : "•")
                            .font(.system(style))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(!ordered)
                        InlineText(item, from: source)
                            .font(.system(style))
                            .foregroundStyle(secondary ? .secondary : .primary)
                            .lineSpacing(2)
                    }
                }
            }
        case .table(let header, let rows):
            TableBlockView(header: header, rows: rows, source: source)
        case .equation(let equation):
            EquationBlockView(equation: equation)
        case .diagram(let text):
            DiagramBlockView(text: text)
        }
    }
}

// MARK: - Equation

/// A formula in a box, with its variables named under it.
private struct EquationBlockView: View {
    let equation: Equation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(equation.formula.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.callout, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !equation.variables.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(equation.variables.enumerated()), id: \.offset) { _, variable in
                        (Text(variable.name).font(.system(.footnote, design: .serif).italic())
                         + Text("  " + variable.meaning).font(.footnote).foregroundColor(.secondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Diagram

/// A plain-text diagram in the monospaced face. It never wraps: a line wider
/// than the screen scrolls sideways.
private struct DiagramBlockView: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .lineSpacing(3)
                .fixedSize()
                .padding(12)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 1))
    }
}

// MARK: - Table

/// A table fitted to the width it has: each column gets its natural width
/// where it can, the widest columns share what is left and wrap. When even
/// that would make a column narrower than a short word, the table keeps a
/// minimum width per column and scrolls sideways.
private struct TableBlockView: View {
    let header: [String]
    let rows: [[String]]
    let source: ArticleID

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0

    var body: some View {
        if typeSize.isAccessibilitySize {
            stacked
        } else {
            grid
        }
    }

    /// At accessibility sizes no column is wide enough for its words, so
    /// each row becomes a record: its first cell, then each other cell under
    /// its column's heading.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    InlineText(row.first ?? "", from: source)
                        .font(.footnote.weight(.semibold))
                    ForEach(Array(row.enumerated().dropFirst()), id: \.offset) { c, cell in
                        if !cell.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                if c < header.count, !header[c].isEmpty {
                                    InlineText(header[c], from: source)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                InlineText(cell, from: source).font(.footnote)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
    }

    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            TableLayout(columns: header.count, targetWidth: width) {
                ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                    self.cell(cell, header: true)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        self.cell(cell, header: false)
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
    }

    private func cell(_ text: String, header: Bool) -> some View {
        InlineText(text, from: source)
            .font(.footnote.weight(header ? .semibold : .regular))
            .foregroundStyle(header ? .secondary : .primary)
            .padding(.vertical, 7)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottom) { Divider() }
    }
}

/// Lays out cells in row-major order on a grid whose column widths fit
/// `targetWidth` (see `fit`).
struct TableLayout: Layout {
    let columns: Int
    /// The width to fit; zero lays the table out at its natural width.
    let targetWidth: CGFloat

    /// No column is narrower than a short word at the default text size.
    static let minColumnWidth: CGFloat = 64
    /// A single long cell does not make its column wider than this before
    /// it wraps.
    static let maxColumnWidth: CGFloat = 280

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = columnWidths(subviews)
        let heights = rowHeights(subviews, widths: widths)
        return CGSize(width: widths.reduce(0, +), height: heights.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = columnWidths(subviews)
        let heights = rowHeights(subviews, widths: widths)
        var y = bounds.minY
        for (r, height) in heights.enumerated() {
            var x = bounds.minX
            for c in 0..<columns {
                let i = r * columns + c
                guard i < subviews.count else { break }
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: widths[c], height: height))
                x += widths[c]
            }
            y += height
        }
    }

    private func rowHeights(_ subviews: Subviews, widths: [CGFloat]) -> [CGFloat] {
        guard columns > 0 else { return [] }
        let rowCount = (subviews.count + columns - 1) / columns
        return (0..<rowCount).map { r in
            (0..<columns).reduce(0) { tallest, c in
                let i = r * columns + c
                guard i < subviews.count else { return tallest }
                return max(tallest, subviews[i].sizeThatFits(ProposedViewSize(width: widths[c], height: nil)).height)
            }
        }
    }

    private func columnWidths(_ subviews: Subviews) -> [CGFloat] {
        var natural = Array(repeating: Self.minColumnWidth, count: columns)
        for (i, subview) in subviews.enumerated() where columns > 0 {
            let width = subview.sizeThatFits(.unspecified).width.rounded(.up)
            natural[i % columns] = max(natural[i % columns], min(width, Self.maxColumnWidth))
        }
        return Self.fit(natural, to: targetWidth)
    }

    /// Column widths for a target width. Natural widths that fit are
    /// stretched in proportion to fill it. Otherwise each column narrower
    /// than an equal share keeps its natural width and the rest share what
    /// is left equally; no column goes under the minimum.
    static func fit(_ natural: [CGFloat], to target: CGFloat) -> [CGFloat] {
        guard target > 0, !natural.isEmpty else { return natural }
        let total = natural.reduce(0, +)
        if total <= target {
            return natural.map { $0 + (target - total) * $0 / total }
        }
        var widths = natural
        var remaining = target
        var open = Array(natural.indices)
        while !open.isEmpty {
            let share = remaining / CGFloat(open.count)
            let small = open.filter { natural[$0] <= share }
            if small.isEmpty {
                for i in open { widths[i] = share }
                break
            }
            for i in small { remaining -= natural[i] }
            open.removeAll { small.contains($0) }
        }
        return widths.map { max($0, minColumnWidth) }
    }
}
