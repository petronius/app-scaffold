#!/usr/bin/env swift
//
// Reads `Copy/copy.tsv` and writes
// `Core/Sources/AppText/Copy.generated.swift`.
//
// Run it through `Scripts/gen-copy.sh`, which knows where the repository root
// is and carries the `--check` form the CI tiers use.
//
// The table is the source of truth for every string the user reads. The
// generator turns each dotted key into a nested enum path, so a call site reads
// `Copy.item.created(day: "9 Nov 2026")` and a typo in a key or a
// missing argument is a compile error rather than a wrong sentence on screen.
// Interpolation stays in Swift, so the core's pure functions stay pure.

import Foundation

// MARK: - Failing

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("gen-copy: \(message)\n".utf8))
    exit(1)
}

// MARK: - Arguments

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2 else {
    fail("usage: gen-copy.swift <copy.tsv> <Copy.generated.swift>")
}
let tablePath = arguments[0]
let outputPath = arguments[1]

// MARK: - The table

struct Row {
    var key: String
    var text: String
    var params: [(name: String, type: String)]
}

guard let raw = try? String(contentsOfFile: tablePath, encoding: .utf8) else {
    fail("cannot read \(tablePath)")
}

// A TSV never needs quoting, which is the whole reason the table is one: a
// line is its columns, split on tabs, and copy is full of commas and quote
// marks that a CSV would make unreadable.
let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
guard let header = lines.first else { fail("\(tablePath) is empty") }
let columns = header.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
guard columns.prefix(3) == ["key", "text", "params"] else {
    fail("\(tablePath): the first three columns must be key, text, params")
}

/// A key segment becomes a Swift identifier as it stands, so one that is a
/// keyword (`where`, `in`, `default`) breaks the build of the generated
/// file. Refused here, at the table, with the line to fix.
let swiftKeywords: Set<String> = [
    "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit",
    "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard", "if",
    "import", "in", "init", "inout", "internal", "is", "let", "nil", "open", "operator", "private",
    "protocol", "public", "repeat", "rethrows", "return", "self", "Self", "static", "struct", "subscript",
    "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while", "Any", "Type",
]

var rows: [Row] = []
var seenKeys: Set<String> = []
for (index, line) in lines.enumerated().dropFirst() {
    let number = index + 1
    if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard fields.count >= 3 else { fail("\(tablePath):\(number): fewer than three columns") }
    let key = fields[0]
    let text = fields[1]
    guard !key.isEmpty else { fail("\(tablePath):\(number): empty key") }
    guard !seenKeys.contains(key) else { fail("\(tablePath):\(number): duplicate key \(key)") }
    seenKeys.insert(key)
    for segment in key.split(separator: ".") where swiftKeywords.contains(String(segment)) {
        fail("\(tablePath):\(number): `\(segment)` in \(key) is a Swift keyword; rename the segment")
    }

    var params: [(name: String, type: String)] = []
    let paramField = fields[2].trimmingCharacters(in: .whitespaces)
    if !paramField.isEmpty {
        for part in paramField.split(separator: ",") {
            let pair = part.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2, !pair[0].isEmpty, !pair[1].isEmpty else {
                fail("\(tablePath):\(number): params must read `name:Type`, comma separated")
            }
            params.append((pair[0], pair[1]))
        }
    }
    rows.append(Row(key: key, text: text, params: params))
}

// MARK: - The tree

final class Node {
    var children: [String: Node] = [:]
    var childOrder: [String] = []
    var leaf: Row?

    func child(_ name: String) -> Node {
        if let existing = children[name] { return existing }
        let node = Node()
        children[name] = node
        childOrder.append(name)
        return node
    }
}

let root = Node()
for row in rows.sorted(by: { $0.key < $1.key }) {
    let parts = row.key.split(separator: ".").map(String.init)
    guard parts.count >= 2 else { fail("key \(row.key) needs at least one dot: area.element") }
    var node = root
    for part in parts.dropLast() {
        node = node.child(part)
        if node.leaf != nil { fail("key \(row.key) is nested under \(part), which is itself a string") }
    }
    let name = parts[parts.count - 1]
    let leafNode = node.child(name)
    guard leafNode.leaf == nil, leafNode.children.isEmpty else {
        fail("key \(row.key) collides with another key")
    }
    leafNode.leaf = row
}

// MARK: - Emitting

/// The text as a Swift string literal, with the table's `{placeholder}` braces
/// turned into interpolations of the declared parameters.
func literal(_ row: Row) -> String {
    var out = "\""
    var name = ""
    var inPlaceholder = false
    var used: Set<String> = []
    for character in row.text {
        if inPlaceholder {
            if character == "}" {
                guard row.params.contains(where: { $0.name == name }) else {
                    fail("\(row.key): {\(name)} is not declared in params")
                }
                used.insert(name)
                out += "\\(\(name))"
                name = ""
                inPlaceholder = false
            } else {
                name.append(character)
            }
            continue
        }
        switch character {
        case "{": inPlaceholder = true
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\t": out += "\\t"
        default: out.append(character)
        }
    }
    guard !inPlaceholder else { fail("\(row.key): an unclosed { in the text") }
    for parameter in row.params where !used.contains(parameter.name) {
        fail("\(row.key): \(parameter.name) is declared in params and never used")
    }
    return out + "\""
}

func emit(_ node: Node, name: String, indent: String, into out: inout String) {
    if let row = node.leaf {
        if row.params.isEmpty {
            out += "\(indent)public static let \(name) = \(literal(row))\n"
        } else {
            let signature = row.params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
            out += "\(indent)public static func \(name)(\(signature)) -> String {\n"
            out += "\(indent)    \(literal(row))\n"
            out += "\(indent)}\n"
        }
        return
    }
    out += "\(indent)public enum \(name) {\n"
    for child in node.childOrder.sorted() {
        emit(node.children[child]!, name: child, indent: indent + "    ", into: &out)
    }
    out += "\(indent)}\n"
}

var output = """
// Generated by Scripts/gen-copy.sh from Copy/copy.tsv. Do not edit.
//
// Every string the user reads lives in that table: edit the row, run the
// script, commit both. `Scripts/gen-copy.sh --check` fails when this file is
// stale.

import Foundation

public enum Copy {

"""
// An empty table still emits the enum, so a call site written before its row
// fails to compile on the missing member rather than on the missing type.
for child in root.childOrder.sorted() {
    emit(root.children[child]!, name: child, indent: "    ", into: &output)
}
output += "}\n"

let existing = try? String(contentsOfFile: outputPath, encoding: .utf8)
if existing != output {
    do {
        try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    } catch {
        fail("cannot write \(outputPath): \(error)")
    }
}
print("gen-copy: \(rows.count) row\(rows.count == 1 ? "" : "s") -> \(outputPath)")
