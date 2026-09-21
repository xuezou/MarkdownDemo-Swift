import Testing
@testable import MarkdownDemo

struct MarkdownTextStatisticsTests {
    @Test func emptyDocument() {
        let result = MarkdownTextStatistics("")
        #expect(result.words == 0)
        #expect(result.characters == 0)
        #expect(result.lines == 0)
    }

    @Test func wordsIgnoreMarkdownPunctuation() {
        let result = MarkdownTextStatistics("# Hello **world**\n")
        #expect(result.words == 2)
        #expect(result.characters == 18)
        #expect(result.lines == 2)
    }

    @Test func countsGraphemesAndWindowsLineEndings() {
        let result = MarkdownTextStatistics("你好👨‍👩‍👧‍👦\r\nSwift\r\n")
        #expect(result.characters == 10)
        #expect(result.lines == 3)
        #expect(result.words >= 2)
    }
}
