//
//  MarkdownEditorDocument.swift
//  MarkdownDemo
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MarkdownEditorDocument: FileDocument {
    nonisolated static let defaultMarkdown = """
    # Mano

    Start writing on the left. The rendered preview updates on the right.

    - Native SwiftUI
    - Custom Markdown rendering
    - Small enough to study and reuse

    ```swift
    print("Hello, Markdown")
    ```
    """

    nonisolated static var readableContentTypes: [UTType] {
        [markdownContentType, .plainText]
    }

    nonisolated static var writableContentTypes: [UTType] {
        readableContentTypes
    }

    var markdown: String

    nonisolated init(markdown: String = MarkdownEditorDocument.defaultMarkdown) {
        self.markdown = markdown
    }

    nonisolated init(data: Data) throws {
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownEditorDocumentError.invalidTextEncoding
        }
        self.init(markdown: markdown)
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw MarkdownEditorDocumentError.invalidTextEncoding
        }
        try self.init(data: data)
    }

    nonisolated var fileData: Data {
        Data(markdown.utf8)
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: fileData)
    }

    nonisolated private static var markdownContentType: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }
}

enum MarkdownEditorDocumentError: LocalizedError, Equatable {
    case invalidTextEncoding

    var errorDescription: String? {
        switch self {
        case .invalidTextEncoding:
            return "The selected file is not valid UTF-8 text."
        }
    }
}
