import Foundation
import Testing
@testable import AppText

struct FormatTests {
    @Test func aHalfRoundsAwayFromZero() {
        #expect(Format.number(102.5, decimals: 0) == "103")
        #expect(Format.number(0.125, decimals: 2) == "0.13")
        #expect(Format.number(-2.5, decimals: 0) == Format.minus + "3")
    }

    @Test func negativesTakeTheMinusSignAndZeroTakesNone() {
        #expect(Format.number(-1.46, decimals: 2) == "\u{2212}1.46")
        #expect(Format.number(-0.004, decimals: 2) == "0.00")
        #expect(Format.number(5, decimals: 1, plusSign: true) == "+5.0")
    }

    @Test func groupingStartsAtFiveDigits() {
        #expect(Format.grouped(2026) == "2026")
        #expect(Format.grouped(15000) == "15\u{202F}000")
        #expect(Format.grouped(861891) == "861\u{202F}891")
    }

    @Test func countsUseTheCopyTableForms() {
        #expect(Format.count(1, one: Copy.item.count.one, other: Copy.item.count.other(count:)) == "1 item")
        #expect(Format.count(3, one: Copy.item.count.one, other: Copy.item.count.other(count:)) == "3 items")
    }

    @Test func aFigureThatCannotBeWorkedOutShowsTheMark() {
        #expect(Format.number(.nan, decimals: 1) == Copy.figure.noValue)
        #expect(Format.percent(.infinity) == Copy.figure.noValue)
    }
}

/// The one-formatting rule (`CLAUDE.md`): no shown figure becomes text
/// outside `Format`. This scans every Swift source the app ships for the
/// calls that round differently.
struct FormattingSourceScanTests {
    static let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let folders = ["App/Sources", "WatchApp/Sources", "Widget/Sources", "WatchWidget/Sources",
                          "Shared/Sources", "Core/Sources"]

    /// `String(format:` rounds a half to even; a number format style rounds
    /// by the locale's rules.
    static let forbidden = ["String(format:", ".formatted(.number", ".formatted(.percent", "NumberFormatter("]

    @Test func noSourceFormatsAFigureOutsideFormat() throws {
        var offenders: [String] = []
        for folder in Self.folders {
            let url = Self.root.appending(path: folder)
            guard let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in files where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                for (number, line) in text.components(separatedBy: "\n").enumerated() {
                    let code = line.split(separator: "//", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
                    for pattern in Self.forbidden where code.contains(pattern) {
                        offenders.append("\(file.path(percentEncoded: false)):\(number + 1): \(pattern)")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, "Format figures through AppText.Format:\n\(offenders.joined(separator: "\n"))")
    }
}
