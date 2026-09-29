import Testing
@testable import MarkdownDemo

@MainActor
struct MarkdownCodeBlockTests {
    @Test func preservesCodeWhitespaceAndExcludesFences() {
        let blocks = MarkdownPreviewBlockParser.parse("```swift\n  let x = 1\n\n  print(x)\n```")
        #expect(blocks == [.code(language: "swift", source: "  let x = 1\n\n  print(x)\n")])
    }

    @Test func treatsTablesAndShorterFencesInsideCodeAsLiteral() {
        let blocks = MarkdownPreviewBlockParser.parse("````md\n| A | B |\n| --- | --- |\n```\n````")
        #expect(blocks == [.code(language: "md", source: "| A | B |\n| --- | --- |\n```\n")])
    }

    @Test func supportsTildesEmptyAndUnclosedBlocks() {
        #expect(MarkdownPreviewBlockParser.parse("~~~\n~~~") == [.code(language: "", source: "")])
        #expect(MarkdownPreviewBlockParser.parse("~~~text\n x\n\n") == [.code(language: "text", source: " x\n\n")])
        #expect(MarkdownPreviewBlockParser.parse("```\n x") == [.code(language: "", source: " x")])
    }

    @Test func preservesCRLFAndSeparatesSurroundingText() {
        let blocks = MarkdownPreviewBlockParser.parse("Before\r\n```txt\r\n a\r\n```\r\nAfter")
        #expect(blocks == [.markdown("Before"), .code(language: "txt", source: " a\r\n"), .markdown("After")])
    }

    @Test func tabIndentedFenceDoesNotCloseCodeOrConsumeFollowingText() {
        let blocks = MarkdownPreviewBlockParser.parse("```text\n\t```\nstill code\n```\nAfter")
        #expect(blocks == [.code(language: "text", source: "\t```\nstill code\n"), .markdown("After")])
        #expect(MarkdownPreviewBlockParser.parse("\t```text\nAfter") == [.markdown("```text\nAfter")])
    }
}
