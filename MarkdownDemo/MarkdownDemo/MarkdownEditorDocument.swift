//
//  MarkdownEditorDocument.swift
//  MarkdownDemo
//

import Foundation

@Observable
final class MarkdownEditorDocument {
    static let defaultMarkdown = """
    # Markdown Lab

    Start writing on the left. The rendered preview updates on the right.

    - Native SwiftUI
    - Custom Markdown rendering
    - Small enough to study and reuse

    ```swift
    print("Hello, Markdown")
    ```
    """

    var markdown: String {
        didSet {
            guard isTrackingChanges else { return }
            isDirty = markdown != savedMarkdown
        }
    }

    private(set) var fileURL: URL?
    private(set) var isDirty: Bool

    private var savedMarkdown: String
    private var isTrackingChanges = true

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled.md"
    }

    init(markdown: String = MarkdownEditorDocument.defaultMarkdown, fileURL: URL? = nil) {
        self.markdown = markdown
        self.fileURL = fileURL
        self.savedMarkdown = markdown
        self.isDirty = false
    }

    func load(from url: URL) throws {
        let loadedMarkdown = try String(contentsOf: url, encoding: .utf8)
        replaceContent(loadedMarkdown, fileURL: url, markDirty: false)
    }

    func save(to url: URL? = nil) throws {
        let destination = url ?? fileURL
        guard let destination else {
            throw MarkdownEditorDocumentError.missingFileURL
        }

        try markdown.write(to: destination, atomically: true, encoding: .utf8)
        replaceContent(markdown, fileURL: destination, markDirty: false)
    }

    private func replaceContent(_ newMarkdown: String, fileURL: URL?, markDirty: Bool) {
        isTrackingChanges = false
        markdown = newMarkdown
        self.fileURL = fileURL
        savedMarkdown = newMarkdown
        isDirty = markDirty
        isTrackingChanges = true
    }
}

enum MarkdownEditorDocumentError: LocalizedError, Equatable {
    case missingFileURL

    var errorDescription: String? {
        switch self {
        case .missingFileURL:
            return "Choose a file location before saving this Markdown document."
        }
    }
}
