import Foundation

struct MarkdownTextStatistics: Equatable, Sendable {
    let words: Int
    let characters: Int
    let lines: Int

    nonisolated init(_ text: String) {
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex,
                                 options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            words += 1
        }
        self.words = words
        characters = text.count
        lines = text.isEmpty ? 0 : 1 + text.filter(\.isNewline).count
    }
}
