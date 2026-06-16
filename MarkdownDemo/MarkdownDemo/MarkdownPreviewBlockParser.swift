//
//  MarkdownPreviewBlockParser.swift
//  MarkdownDemo
//

import Foundation

enum MarkdownPreviewBlock: Equatable {
    case markdown(String)
    case mermaid(String)
    case table(MarkdownTable)
}

enum MarkdownPreviewBlockParser {
    nonisolated static func parse(_ markdown: String) -> [MarkdownPreviewBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownPreviewBlock] = []
        var markdownBuffer: [String] = []
        var index = 0

        func flushMarkdown() {
            let text = markdownBuffer.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.markdown(text))
            }
            markdownBuffer.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "```mermaid" {
                flushMarkdown()
                index += 1

                var mermaidLines: [String] = []
                while index < lines.count {
                    let currentLine = lines[index]
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                        break
                    }
                    mermaidLines.append(currentLine)
                    index += 1
                }

                blocks.append(.mermaid(
                    mermaidLines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            } else if let tableBlock = parseTableBlock(lines, startingAt: index) {
                flushMarkdown()
                blocks.append(.table(tableBlock.table))
                index = tableBlock.endIndex
                continue
            } else {
                markdownBuffer.append(line)
            }
            index += 1
        }

        flushMarkdown()
        return blocks
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
