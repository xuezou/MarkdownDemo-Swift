//
//  MarkdownTableParser.swift
//  MarkdownDemo
//

import Foundation

struct MarkdownTable: Equatable {
    enum Alignment: Equatable {
        case left
        case center
        case right
    }

    let headers: [String]
    let alignments: [Alignment]
    let rows: [[String]]
}

enum MarkdownTableParser {
    nonisolated static func parse(_ markdown: String) -> MarkdownTable? {
        let lines = markdown.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }

        let headers = parseCells(lines[0])
        let separatorCells = parseCells(lines[1])
        guard !headers.isEmpty,
              separatorCells.count == headers.count,
              separatorCells.allSatisfy(isSeparatorCell)
        else {
            return nil
        }

        let rows = lines.dropFirst(2).map { line in
            normalizedRow(parseCells(line), columnCount: headers.count)
        }

        return MarkdownTable(
            headers: headers,
            alignments: separatorCells.map(parseAlignment),
            rows: rows
        )
    }

    nonisolated static func parseCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    nonisolated private static func normalizedRow(_ cells: [String], columnCount: Int) -> [String] {
        if cells.count == columnCount {
            return cells
        }

        if cells.count > columnCount {
            return Array(cells.prefix(columnCount))
        }

        return cells + Array(repeating: "", count: columnCount - cells.count)
    }

    nonisolated private static func isSeparatorCell(_ cell: String) -> Bool {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let withoutColons = trimmed.replacingOccurrences(of: ":", with: "")
        return withoutColons.count >= 3 && withoutColons.allSatisfy { $0 == "-" }
    }

    nonisolated private static func parseAlignment(_ cell: String) -> MarkdownTable.Alignment {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let hasLeadingColon = trimmed.hasPrefix(":")
        let hasTrailingColon = trimmed.hasSuffix(":")

        switch (hasLeadingColon, hasTrailingColon) {
        case (true, true):
            return .center
        case (false, true):
            return .right
        default:
            return .left
        }
    }
}
