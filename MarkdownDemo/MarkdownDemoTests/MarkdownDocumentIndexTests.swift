import Foundation
import Testing
@testable import MarkdownDemo

@MainActor
struct MarkdownDocumentIndexTests {
    @Test func collectsRealHeadingsAndIgnoresCodeAndEscapes() {
        let source = """
        # **Overview**
        Intro
        ## API `client`

        ```markdown
        # Not a heading
        ```

        ~~~
        ## Also code
        ~~~

        \\# Escaped

        Setext title
        ------------
        """
        let index = MarkdownDocumentIndex(source)
        #expect(index.headings.map(\.title) == ["Overview", "API client", "Setext title"])
        #expect(index.headings.map(\.level) == [1, 2, 2])
        #expect(index.blocks.contains { $0.content == .markdown("## Setext title") })
    }

    @Test func sourcePositionsUseUTF16ForChineseEmojiAndCRLF() {
        let source = "开头😀\r\n\r\n# 安装\r\n内容\r\n\r\n## 后续\r\n"
        let text = source as NSString
        let index = MarkdownDocumentIndex(source)
        #expect(index.headings.map(\.id) == [text.range(of: "# 安装").location,
                                            text.range(of: "## 后续").location])
        let contentOffset = text.range(of: "内容").location
        #expect(index.block(atUTF16Offset: contentOffset)?.content == .markdown("内容"))
        #expect(index.heading(atUTF16Offset: contentOffset)?.title == "安装")
        #expect(index.block(atUTF16Offset: text.length)?.id == index.blocks.last?.id)
        #expect(index.heading(atUTF16Offset: 0) == nil)
    }

    @Test func anchorsHandleDuplicatesCollisionsAndEncodedChinese() {
        let index = MarkdownDocumentIndex("# Intro\n# Intro\n# Intro-1\n# 中文 标题\n# [Link](https://example.com)")
        #expect(index.headings.map(\.anchor) == ["intro", "intro-1", "intro-1-1", "中文-标题", "link"])
        #expect(index.heading(forAnchor: "%E4%B8%AD%E6%96%87-%E6%A0%87%E9%A2%98")?.title == "中文 标题")
        #expect(index.heading(forAnchor: "missing") == nil)
    }

    @Test func sourcePositionsSupportLegacyCRLineEndings() {
        let source = "# First\r\rText😀\r\r## Second"
        let index = MarkdownDocumentIndex(source)
        let offset = (source as NSString).range(of: "## Second").location
        #expect(index.headings.map(\.title) == ["First", "Second"])
        #expect(index.headings.last?.id == offset)
        #expect(index.block(atUTF16Offset: offset)?.content == .markdown("## Second"))
    }

    @Test func preservesSpecialPreviewBlocksAndMapsTheirSourcePositions() {
        let source = """
        # Document

        | A | B |
        | --- | --- |
        | 1 | 2 |

        ```mermaid
        flowchart TD
            A --> B
        ```

        ```swift
          let x = 1
        ```

        Last paragraph.
        """
        let index = MarkdownDocumentIndex(source)
        #expect(index.blocks.count == 5)
        if case .table(let table) = index.blocks[1].content {
            #expect(table.rows.count == 1)
        } else {
            Issue.record("Expected a native table block")
        }
        #expect(index.blocks[2].content == .mermaid("flowchart TD\n    A --> B"))
        #expect(index.blocks[3].content == .code(language: "swift", source: "  let x = 1\n"))
        let offset = (source as NSString).range(of: "A --> B").location
        #expect(index.block(atUTF16Offset: offset)?.id == 2)
    }

    @Test func nestedHeadingsPointToTheirContainingPreviewBlock() {
        let index = MarkdownDocumentIndex("> ## Quoted\n> text\n\n- ## Nested\n\n# End")
        #expect(index.headings.map(\.title) == ["Quoted", "Nested", "End"])
        #expect(index.headings.allSatisfy { heading in index.blocks.contains { $0.id == heading.blockID } })
    }

    @Test func rebuildsAfterEditsAndHandlesEmptyDocuments() {
        let original = MarkdownDocumentIndex("# One\n\nText\n\n# Two")
        let updated = MarkdownDocumentIndex("New intro😀\n\n# One\n\nText\n\n# Renamed")
        #expect(updated.headings.last?.anchor == "renamed")
        #expect(updated.headings.first!.id > original.headings.first!.id)
        #expect(MarkdownDocumentIndex("").blocks.isEmpty)
        #expect(MarkdownDocumentIndex("\n \n").headings.isEmpty)
        #expect(MarkdownDocumentIndex("").block(atUTF16Offset: 0) == nil)
    }

    @Test func preservesEscapedHeadingSyntaxInPreview() {
        let atx = MarkdownDocumentIndex("# \\*literal\\* and \\[link\\](url)")
        #expect(atx.blocks.first?.content == .markdown("# \\*literal\\* and \\[link\\](url)"))
        let setext = MarkdownDocumentIndex("\\*literal\\*\n---")
        #expect(setext.blocks.first?.content == .markdown("## \\*literal\\*"))
        let hashTitle = MarkdownDocumentIndex("#literal\n---")
        #expect(hashTitle.blocks.first?.content == .markdown("## #literal"))
    }

    @Test func anchorNamesPreserveLiteralHyphensAndQuotes() {
        let index = MarkdownDocumentIndex("# foo--bar\n# foo---bar\n# \"quoted\" title")
        #expect(index.headings.map(\.title) == ["foo--bar", "foo---bar", "\"quoted\" title"])
        #expect(index.heading(forAnchor: "foo--bar") != nil)
        #expect(index.heading(forAnchor: "foo---bar") != nil)
    }

    @Test func nestedCodeAndHeadingHaveSeparateSourceSpans() {
        let source = "- First\n  ```swift\n  let x = 1\n  ```\n  ## Nested\n  tail\n\n# End"
        let index = MarkdownDocumentIndex(source)
        let text = source as NSString
        #expect(index.block(atUTF16Offset: text.range(of: "First").location)?.content == .markdown("- First"))
        #expect(index.block(atUTF16Offset: text.range(of: "let x").location)?.content ==
                .code(language: "swift", source: "  let x = 1\n"))
        let nestedOffset = text.range(of: "  ## Nested").location
        #expect(index.headings.first?.title == "Nested")
        #expect(index.headings.first?.blockID == index.block(atUTF16Offset: nestedOffset)?.id)
        #expect(Set(index.blocks.map { $0.sourceRange.location }).count == index.blocks.count)
    }
}
