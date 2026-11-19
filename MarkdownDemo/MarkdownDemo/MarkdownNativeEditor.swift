#if os(macOS)
import AppKit
import Combine
import SwiftUI

// Retain the native editor across layout changes, including its undo and selection state.
final class MarkdownNativeEditorController: NSObject, ObservableObject, NSTextViewDelegate {
    let scrollView: NSScrollView
    let textView: NSTextView
    var text: Binding<String>?
    @Published private(set) var selectionLocation = 0
    private var pendingFindAction: NSTextFinder.Action?
    private var pendingNavigationOffset: Int?

    override init() {
        scrollView = NSScrollView()
        let nativeTextView = MarkdownEditorTextView(frame: .zero)
        textView = nativeTextView
        super.init()
        textView.delegate = self
        nativeTextView.onWindowAttached = { [weak self] in
            self?.performPendingNavigation()
            self?.performPendingFind()
        }
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

    func navigate(toUTF16Offset offset: Int, focus: Bool) {
        pendingNavigationOffset = offset
        performPendingNavigation()
        if focus { textView.window?.makeFirstResponder(textView) }
    }

    func insertImageReferences(_ references: [String], replacing range: NSRange, expectedText: String) -> Bool {
        let source = textView.string as NSString
        guard !references.isEmpty, textView.isEditable, !textView.hasMarkedText(),
              textView.string.utf16.elementsEqual(expectedText.utf16), range.location >= 0, range.location <= source.length,
              range.length >= 0, range.length <= source.length - range.location,
              Range(range, in: expectedText) != nil else { return false }
        let before = source.substring(to: range.location)
        let after = source.substring(from: range.location + range.length)
        let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : (before.hasSuffix("\n") ? "\n" : "\n\n")
        let suffix = after.hasPrefix("\n\n") ? "" : (after.hasPrefix("\n") ? "\n" : "\n\n")
        let insertion = prefix + references.joined(separator: "\n\n") + suffix
        textView.breakUndoCoalescing()
        textView.insertText(insertion, replacementRange: range)
        textView.breakUndoCoalescing()
        textView.undoManager?.setActionName("Insert Image")
        return textView.string == before + insertion + after
    }

    private func performPendingNavigation() {
        guard let offset = pendingNavigationOffset, textView.window != nil else { return }
        pendingNavigationOffset = nil
        let range = NSRange(location: max(0, min(offset, textView.string.utf16.count)), length: 0)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
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
        publishSelection()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        publishSelection()
    }

    private func publishSelection() {
        // NSTextView also sends selection notifications during SwiftUI view updates.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.textView.hasMarkedText() else { return }
            let location = self.textView.selectedRange().location
            if self.selectionLocation != location { self.selectionLocation = location }
        }
    }
}

private final class MarkdownEditorTextView: NSTextView {
    var onWindowAttached: (() -> Void)?
    var onImageDrop: (([URL], NSRange) -> Bool)?

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        let types = super.acceptableDragTypes
        return types.contains(.fileURL) ? types : types + [.fileURL]
    }

    override func dragOperation(for dragInfo: NSDraggingInfo, type: NSPasteboard.PasteboardType) -> NSDragOperation {
        let operation = super.dragOperation(for: dragInfo, type: type)
        return onImageDrop != nil && imageURLs(from: dragInfo.draggingPasteboard) != nil ? .copy : operation
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let onImageDrop, let urls = imageURLs(from: sender.draggingPasteboard) else {
            return super.performDragOperation(sender)
        }
        let point = convert(sender.draggingLocation, from: nil)
        let offset = min(characterIndexForInsertion(at: point), string.utf16.count)
        return onImageDrop(urls, NSRange(location: offset, length: 0))
    }

    private func imageURLs(from pasteboard: NSPasteboard) -> [URL]? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty, urls.allSatisfy({ ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) })
        else { return nil }
        return urls
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onWindowAttached?() }
    }
}

struct MarkdownNativeEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: MarkdownNativeEditorController
    let theme: MarkdownTheme
    var onImageDrop: (([URL], NSRange) -> Bool)?

    final class Coordinator {
        var onImageDrop: (([URL], NSRange) -> Bool)?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        controller.text = $text
        context.coordinator.onImageDrop = onImageDrop
        (controller.textView as? MarkdownEditorTextView)?.onImageDrop = { [weak coordinator = context.coordinator] urls, range in
            coordinator?.onImageDrop?(urls, range) ?? false
        }
        return controller.scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = controller.textView
        context.coordinator.onImageDrop = onImageDrop
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
        scrollView.appearance = NSAppearance(named: .darkAqua)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        (scrollView.documentView as? MarkdownEditorTextView)?.onImageDrop = nil
        coordinator.onImageDrop = nil
    }
}
#endif
