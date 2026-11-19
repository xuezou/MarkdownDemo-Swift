#if os(macOS)
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class MarkdownImageImportController: NSObject, ObservableObject {
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    var documentURL: URL?
    private weak var editor: MarkdownNativeEditorController?
    private weak var nativeDocument: NSDocument?
    private var panel: NSOpenPanel?
    private var pending: Request?
    private var importTask: Task<Void, Never>?
    private var operationID = UUID()

    private struct Request: Sendable {
        let urls: [URL]
        let range: NSRange
        let text: String
    }

    func chooseImages(editor: MarkdownNativeEditorController) {
        guard !isBusy, let window = editor.textView.window else { return }
        let range = editor.textView.selectedRange()
        let text = editor.textView.string
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.png, .jpeg]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.prompt = "Insert Images"
        panel = picker
        isBusy = true
        let pickerID = UUID()
        operationID = pickerID
        picker.beginSheetModal(for: window) { [weak self, weak editor] response in
            guard let self, self.isBusy, self.operationID == pickerID else { return }
            self.panel = nil
            self.isBusy = false
            guard response == .OK, let editor else { return }
            _ = self.begin(Request(urls: picker.urls, range: range, text: text), editor: editor)
        }
    }

    @discardableResult
    func add(_ urls: [URL], at range: NSRange, editor: MarkdownNativeEditorController) -> Bool {
        begin(Request(urls: urls, range: range, text: editor.textView.string), editor: editor)
    }

    func cancel() {
        operationID = UUID()
        importTask?.cancel()
        importTask = nil
        isBusy = false
        panel?.cancel(nil)
        panel = nil
        pending = nil
        editor = nil
        nativeDocument = nil
    }

    private func begin(_ request: Request, editor: MarkdownNativeEditorController) -> Bool {
        guard !isBusy, !request.urls.isEmpty, !editor.textView.hasMarkedText(),
              editor.textView.string.utf16.elementsEqual(request.text.utf16),
              let window = editor.textView.window else { return false }
        self.editor = editor
        nativeDocument = window.windowController?.document as? NSDocument
        pending = request
        isBusy = true
        operationID = UUID()
        if let url = documentURL ?? nativeDocument?.fileURL {
            performImport(request, documentURL: url)
        } else if let nativeDocument {
            nativeDocument.save(withDelegate: self,
                                didSave: #selector(documentDidSave(_:didSave:contextInfo:)), contextInfo: nil)
        } else {
            finish(error: MarkdownImageError.unsavedDocument)
        }
        return true
    }

    @objc func documentDidSave(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let request = pending, isBusy else { return }
        guard didSave, let url = document.fileURL else {
            finish()
            return
        }
        documentURL = url
        performImport(request, documentURL: url)
    }

    private func performImport(_ request: Request, documentURL: URL) {
        let id = operationID
        importTask = Task { [weak self] in
            guard let self else { return }
            let copying = Task.detached(priority: .userInitiated) {
                try MarkdownImageImporter.copy(request.urls, to: documentURL)
            }
            do {
                let imported = try await withTaskCancellationHandler {
                    try await copying.value
                } onCancel: {
                    copying.cancel()
                }
                guard self.operationID == id else {
                    MarkdownImageImporter.discard(imported)
                    return
                }
                try commit(imported, request: request, documentURL: documentURL)
                finish()
            } catch is CancellationError {
                if self.operationID == id { finish() }
            } catch {
                if self.operationID == id { finish(error: error) }
            }
        }
    }

    private func commit(_ imported: [MarkdownImportedImage], request: Request, documentURL: URL) throws {
        var committed = false
        defer { if !committed { MarkdownImageImporter.discard(imported) } }
        try Task.checkCancellation()
        let currentURL = nativeDocument?.fileURL ?? self.documentURL
        guard currentURL?.standardizedFileURL == documentURL.standardizedFileURL,
              let editor, editor.textView.window != nil,
              editor.insertImageReferences(imported.map(\.markdown), replacing: request.range, expectedText: request.text)
        else { throw CocoaError(.userCancelled, userInfo: [NSLocalizedDescriptionKey:
            "The document changed while images were being imported. Please try again."
        ]) }
        committed = true
    }

    private func finish(error: Error? = nil) {
        if let error { errorMessage = error.localizedDescription }
        isBusy = false
        pending = nil
        importTask = nil
        editor = nil
        nativeDocument = nil
    }
}
#endif
