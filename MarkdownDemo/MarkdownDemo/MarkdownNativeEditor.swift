#if os(macOS)
import AppKit
import Combine
import SwiftUI

// Retain the native editor across layout changes, including its undo and selection state.
final class MarkdownNativeEditorController: NSObject, ObservableObject, NSTextViewDelegate {
    let scrollView: NSScrollView
    let textView: NSTextView
    var text: Binding<String>?
    private var pendingFindAction: NSTextFinder.Action?

    override init() {
        scrollView = NSScrollView()
        let nativeTextView = MarkdownEditorTextView(frame: .zero)
        textView = nativeTextView
        super.init()
        textView.delegate = self
        nativeTextView.onWindowAttached = { [weak self] in self?.performPendingFind() }
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.setAccessibilityIdentifier("markdown.source")
        scrollView.documentView = textView
    }

    func find(replace: Bool) {
        pendingFindAction = replace ? .showReplaceInterface : .showFindInterface
        performPendingFind()
    }

    private func performPendingFind() {
        guard let action = pendingFindAction, let window = textView.window else { return }
        pendingFindAction = nil
        window.makeFirstResponder(textView)
        let item = NSMenuItem()
        item.tag = action.rawValue
        textView.performTextFinderAction(item)
    }

    func textDidChange(_ notification: Notification) {
        text?.wrappedValue = textView.string
    }
}

private final class MarkdownEditorTextView: NSTextView {
    var onWindowAttached: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onWindowAttached?() }
    }
}

struct MarkdownNativeEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: MarkdownNativeEditorController
    let theme: MarkdownTheme

    func makeNSView(context: Context) -> NSScrollView {
        controller.text = $text
        return controller.scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = controller.textView
        controller.text = $text
        if textView.string != text && !textView.hasMarkedText() {
            let selection = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
        textView.textColor = NSColor(theme.text)
        textView.insertionPointColor = NSColor(theme.text)
        textView.backgroundColor = NSColor(theme.editorBackground)
    }

}
#endif
