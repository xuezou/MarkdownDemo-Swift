//
//  MarkdownPreviewBlockParser.swift
//  MarkdownDemo
//

import Foundation

enum MarkdownPreviewBlock: Equatable {
    case markdown(String)
    case mermaid(String)
    case table(MarkdownTable)
    case code(language: String, source: String)
}

struct MarkdownPreviewSourceBlock {
    let content: MarkdownPreviewBlock
    let sourceRange: NSRange
}

enum MarkdownPreviewBlockParser {
    nonisolated static func parse(_ markdown: String) -> [MarkdownPreviewBlock] {
        parseWithSourceRanges(markdown).map(\.content)
    }

    nonisolated static func parseWithSourceRanges(_ markdown: String) -> [MarkdownPreviewSourceBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var offset = 0
        var offsets = lines.map { line in
            defer { offset += line.utf16.count + 1 }
            return offset
        }
        offsets.append(markdown.utf16.count)
        var blocks: [MarkdownPreviewSourceBlock] = []
        var markdownBuffer: [String] = []
        var bufferStart = 0
        var index = 0

        func append(_ content: MarkdownPreviewBlock, from start: Int, to end: Int) {
            blocks.append(MarkdownPreviewSourceBlock(
                content: content,
                sourceRange: NSRange(location: offsets[start], length: offsets[end] - offsets[start])
            ))
        }

        func flushMarkdown() {
            let text = markdownBuffer.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                append(.markdown(text), from: bufferStart, to: index)
            }
            markdownBuffer.removeAll()
        }

        while index < lines.count {
            if let code = parseFencedBlock(lines, startingAt: index) {
                flushMarkdown()
                append(code.block, from: index, to: code.endIndex)
                index = code.endIndex
            } else if let tableBlock = parseTableBlock(lines, startingAt: index) {
                flushMarkdown()
                append(.table(tableBlock.table), from: index, to: tableBlock.endIndex)
                index = tableBlock.endIndex
            } else {
                if markdownBuffer.isEmpty { bufferStart = index }
                markdownBuffer.append(lines[index])
                index += 1
            }
        }

        flushMarkdown()
        return blocks
    }

    nonisolated private static func parseFencedBlock(
        _ lines: [String], startingAt start: Int
    ) -> (block: MarkdownPreviewBlock, endIndex: Int)? {
        guard let fence = openingFence(lines[start]) else { return nil }
        var index = start + 1
        var codeLines: [String] = []
        while index < lines.count {
            let currentLine = lines[index]
            let trimmed = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if hasFenceIndentation(currentLine) && trimmed.count >= fence.count &&
                trimmed.allSatisfy({ $0 == fence.marker }) { break }
            codeLines.append(currentLine)
            index += 1
        }
        var source = codeLines.joined(separator: "\n")
        if index < lines.count && index > start + 1 { source += "\n" }
        let block: MarkdownPreviewBlock = fence.language.lowercased() == "mermaid"
            ? .mermaid(source.trimmingCharacters(in: .whitespacesAndNewlines))
            : .code(language: fence.language, source: source)
        return (block, min(index + 1, lines.count))
    }

    nonisolated private static func openingFence(_ line: String) -> (marker: Character, count: Int, language: String)? {
        guard hasFenceIndentation(line) else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == marker }).count
        guard count >= 3 else { return nil }
        let info = trimmed.dropFirst(count)
        guard marker != "`" || !info.contains("`") else { return nil }
        return (marker, count, info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? "")
    }

    nonisolated private static func hasFenceIndentation(_ line: String) -> Bool {
        let indentation = line.prefix(while: { $0 == " " || $0 == "\t" })
        return indentation.count <= 3 && !indentation.contains("\t")
    }

    nonisolated private static func parseTableBlock(
        _ lines: [String],
        startingAt startIndex: Int
    ) -> (table: MarkdownTable, endIndex: Int)? {
        guard startIndex + 1 < lines.count else {
            return nil
        }

        var tableLines: [String] = []
        var index = startIndex
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("```") || !trimmed.contains("|") {
                break
            }

            tableLines.append(line)
            index += 1
        }

        guard let table = MarkdownTableParser.parse(tableLines.joined(separator: "\n")) else {
            return nil
        }

        return (table, index)
    }
}
