#if os(macOS)
import AppKit
import Combine
import Testing
@testable import MarkdownDemo

@MainActor
struct MarkdownImageImportControllerTests {
    @Test func cancellingFirstSaveLeavesTextAndFilesUntouched() throws {
        let context = ImageImportTestContext()
        defer { context.close() }
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        context.editor.textView.string = "# Unsaved"

        #expect(context.importer.add([source], at: NSRange(location: 9, length: 0), editor: context.editor))
        #expect(context.document.saveWasRequested)
        #expect(context.importer.isBusy)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("assets").path))
        context.importer.documentDidSave(context.document, didSave: false, contextInfo: nil)

        #expect(!context.importer.isBusy)
        #expect(context.importer.errorMessage == nil)
        #expect(context.editor.textView.string == "# Unsaved")
    }

    @Test(.timeLimit(.minutes(1))) func firstSaveContinuesImportAndUndoRetainsTheCopiedFile() async throws {
        let context = ImageImportTestContext()
        defer { context.close() }
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        context.editor.textView.string = "Note"
        #expect(context.importer.add([source], at: NSRange(location: 4, length: 0), editor: context.editor))
        context.document.fileURL = directory.appendingPathComponent("note.md")
        context.importer.documentDidSave(context.document, didSave: true, contextInfo: nil)
        await context.waitForImport()

        #expect(context.importer.errorMessage == nil)
        #expect(context.editor.textView.string.contains("![shot](assets/shot.png)"))
        context.editor.textView.undoManager?.undo()
        #expect(context.editor.textView.string == "Note")
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("assets/shot.png").path))
    }

    @Test(.timeLimit(.minutes(1))) func changesDuringImportDoNotGetOverwrittenAndNewCopiesAreRemoved() async throws {
        let context = ImageImportTestContext()
        defer { context.close() }
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        context.document.fileURL = directory.appendingPathComponent("note.md")
        context.importer.documentURL = context.document.fileURL
        context.editor.textView.string = "Before"
        #expect(context.importer.add([source], at: NSRange(location: 6, length: 0), editor: context.editor))
        context.editor.textView.string = "Edited while copying"
        await context.waitForImport()

        #expect(context.editor.textView.string == "Edited while copying")
        #expect(context.importer.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("assets/shot.png").path))
    }
}

@MainActor
private final class ImageImportTestContext {
    let importer = MarkdownImageImportController()
    let editor = MarkdownNativeEditorController()
    let document = ImageSaveTestDocument()
    let window: ImageImportTestWindow
    let windowController: NSWindowController

    init() {
        window = ImageImportTestWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                                       styleMask: [.titled], backing: .buffered, defer: false)
        windowController = NSWindowController(window: window)
        document.addWindowController(windowController)
        window.contentView = editor.scrollView
        window.makeFirstResponder(editor.textView)
    }

    func waitForImport() async {
        for await busy in importer.$isBusy.values {
            if !busy { return }
        }
    }

    func close() {
        importer.cancel()
        window.contentView = nil
        document.removeWindowController(windowController)
    }
}

private final class ImageSaveTestDocument: NSDocument {
    var saveWasRequested = false

    override func save(withDelegate delegate: Any?, didSave selector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        saveWasRequested = true
    }
}

private final class ImageImportTestWindow: NSWindow {
    private let history = UndoManager()
    override var undoManager: UndoManager? { history }
}
#endif
