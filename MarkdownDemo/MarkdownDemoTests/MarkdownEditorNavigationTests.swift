#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import MarkdownDemo

@MainActor
struct MarkdownEditorNavigationTests {
    @Test func navigationMovesCaretWithoutChangingTextOrUndoHistory() {
        let editor = MarkdownNativeEditorController()
        let window = NavigationTestWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor.scrollView
        let source = "# 第一章😀\n\nText\n\n## Second"
        editor.textView.string = source
        window.makeFirstResponder(editor.textView)
        editor.textView.insertText("!", replacementRange: NSRange(location: source.utf16.count, length: 0))
        editor.textView.breakUndoCoalescing()
        let offset = (source as NSString).range(of: "## Second").location
        #expect(editor.textView.undoManager?.canUndo == true)

        editor.navigate(toUTF16Offset: offset, focus: false)

        #expect(editor.textView.selectedRange() == NSRange(location: offset, length: 0))
        #expect(editor.textView.string == source + "!")
        editor.textView.undoManager?.undo()
        #expect(editor.textView.string == source)
        window.contentView = nil
    }

    @Test func navigationClampsOffsetsAndSurvivesEditorReattachment() {
        let editor = MarkdownNativeEditorController()
        editor.textView.string = "abc"
        editor.navigate(toUTF16Offset: 999, focus: false)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor.scrollView
        #expect(editor.textView.selectedRange().location == 3)
        window.contentView = nil
        editor.navigate(toUTF16Offset: -1, focus: false)
        window.contentView = editor.scrollView
        #expect(editor.textView.selectedRange().location == 0)
        window.contentView = nil
    }

    @Test func selectionPublicationTracksTheLatestCaret() async {
        let editor = MarkdownNativeEditorController()
        editor.textView.string = "text😀"
        editor.textView.setSelectedRange(NSRange(location: 2, length: 0))
        editor.textView.setSelectedRange(NSRange(location: 4, length: 0))
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(editor.selectionLocation == 4)
    }

    @Test func reenabledFollowRequestsAScrollEvenForTheSameBlock() {
        let original = MarkdownPreviewTarget(blockID: 4)
        let stationary = MarkdownPreviewTarget.following(blockID: 4, previous: original, force: false)
        let reenabled = MarkdownPreviewTarget.following(blockID: 4, previous: original, force: true)
        #expect(stationary == original)
        #expect(reenabled.blockID == original.blockID)
        #expect(reenabled.requestID != original.requestID)
        #expect(MarkdownPreviewTarget.following(blockID: 5, previous: original, force: false).blockID == 5)
    }
}

private final class NavigationTestWindow: NSWindow {
    private let history = UndoManager()
    override var undoManager: UndoManager? { history }
}
#endif
