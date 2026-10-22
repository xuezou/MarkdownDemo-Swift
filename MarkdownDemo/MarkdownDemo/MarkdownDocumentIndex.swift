import Foundation
import Markdown

struct MarkdownIndexedBlock: Identifiable, Equatable {
    let id: Int
    let sourceRange: NSRange
    let content: MarkdownPreviewBlock
}

struct MarkdownOutlineHeading: Identifiable, Equatable {
    let id: Int
    let title: String
    let level: Int
    let anchor: String
    let blockID: Int
}

struct MarkdownDocumentIndex {
    let blocks: [MarkdownIndexedBlock]
    let headings: [MarkdownOutlineHeading]

    nonisolated init(_ source: String) {
        let text = source as NSString
        let offsets = Self.lineOffsets(in: text)
        var indexedBlocks: [MarkdownIndexedBlock] = []
        var outline: [MarkdownOutlineHeading] = []
        var usedAnchors = Set<String>()

        for node in Document(parsing: source, options: [.disableSmartOpts]).children {
            guard let range = node.range else { continue }
            let firstLine = max(0, min(range.lowerBound.line - 1, offsets.count - 2))
            let lastLine = max(firstLine, min(range.upperBound.line - 1, offsets.count - 2))
            let start = offsets[firstLine]
            let end = min(text.length, offsets[lastLine + 1])
            let sourceRange = NSRange(location: start, length: end - start)
            let raw = text.substring(with: sourceRange)
            if let heading = node as? Heading {
                indexedBlocks.append(MarkdownIndexedBlock(
                    id: indexedBlocks.count, sourceRange: sourceRange,
                    content: .markdown(Self.headingSource(heading, raw: raw))
                ))
            } else {
                Self.appendBlocks(raw, startingAt: start, to: &indexedBlocks)
            }
            Self.collectHeadings(node, blocks: indexedBlocks, offsets: offsets,
                                 headings: &outline, usedAnchors: &usedAnchors)
        }
        blocks = indexedBlocks
        headings = outline
    }

    nonisolated private static func appendBlocks(
        _ raw: String, startingAt start: Int, to blocks: inout [MarkdownIndexedBlock]
    ) {
        for block in MarkdownPreviewBlockParser.parseWithSourceRanges(raw) {
            blocks.append(MarkdownIndexedBlock(
                id: blocks.count,
                sourceRange: NSRange(location: start + block.sourceRange.location,
                                     length: block.sourceRange.length),
                content: block.content
            ))
        }
    }

    nonisolated private static func headingSource(_ heading: Heading, raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmed.prefix(while: { $0 == "#" })
        let remainder = trimmed.dropFirst(prefix.count)
        if (1...6).contains(prefix.count), remainder.isEmpty || remainder.first?.isWhitespace == true {
            return trimmed
        }
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let title = lines.dropLast().map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        return String(repeating: "#", count: heading.level) + " " + title
    }

    nonisolated func block(atUTF16Offset offset: Int) -> MarkdownIndexedBlock? {
        blocks.last(where: { $0.sourceRange.location <= offset }) ?? blocks.first
    }

    nonisolated func heading(atUTF16Offset offset: Int) -> MarkdownOutlineHeading? {
        headings.last(where: { $0.id <= offset })
    }

    nonisolated func heading(forAnchor anchor: String) -> MarkdownOutlineHeading? {
        let decoded = anchor.removingPercentEncoding ?? anchor
        return headings.first(where: { $0.anchor == decoded })
    }

    nonisolated private static func lineOffsets(in text: NSString) -> [Int] {
        var offsets = [0]
        for index in 0..<text.length {
            let character = text.character(at: index)
            let isStandaloneCR = character == 13 &&
                (index + 1 == text.length || text.character(at: index + 1) != 10)
            if character == 10 || isStandaloneCR { offsets.append(index + 1) }
        }
        offsets.append(text.length)
        return offsets
    }

    nonisolated private static func collectHeadings(
        _ node: Markup, blocks: [MarkdownIndexedBlock], offsets: [Int],
        headings: inout [MarkdownOutlineHeading], usedAnchors: inout Set<String>
    ) {
        if let heading = node as? Heading, let range = heading.range {
            let title = titleText(heading)
            let base = anchor(for: title)
            var candidate = base
            var suffix = 1
            while usedAnchors.contains(candidate) {
                candidate = "\(base)-\(suffix)"
                suffix += 1
            }
            usedAnchors.insert(candidate)
            let line = max(0, min(range.lowerBound.line - 1, offsets.count - 1))
            let blockID = blocks.last(where: { $0.sourceRange.location <= offsets[line] })?.id ?? 0
            headings.append(MarkdownOutlineHeading(
                id: offsets[line], title: title, level: heading.level,
                anchor: candidate, blockID: blockID
            ))
        }
        for child in node.children {
            collectHeadings(child, blocks: blocks, offsets: offsets,
                            headings: &headings, usedAnchors: &usedAnchors)
        }
    }

    nonisolated private static func titleText(_ node: Markup) -> String {
        if let code = node as? InlineCode { return code.code }
        if node is SoftBreak || node is LineBreak { return " " }
        if node is InlineHTML { return "" }
        if node.childCount > 0 { return node.children.map(titleText).joined() }
        return (node as? PlainTextConvertibleMarkup)?.plainText ?? ""
    }

    nonisolated private static func anchor(for title: String) -> String {
        let scalars = title.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) ||
            CharacterSet.whitespaces.contains($0) || $0 == "-" || $0 == "_"
        }
        return String(String.UnicodeScalarView(scalars)).map {
            $0.isWhitespace ? "-" : String($0)
        }.joined()
    }
}
