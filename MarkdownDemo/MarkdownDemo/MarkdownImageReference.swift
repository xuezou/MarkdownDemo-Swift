import Foundation
import Markdown

struct MarkdownImageReference: Equatable, Sendable {
    let destination: String
    let altText: String
    let title: String?

    nonisolated var isRelative: Bool {
        URL(string: destination)?.scheme == nil && !destination.hasPrefix("/")
    }

    nonisolated static func standalone(in node: Markup) -> Self? {
        guard let paragraph = node as? Paragraph, paragraph.childCount == 1,
              let image = paragraph.child(at: 0) as? Markdown.Image,
              let destination = image.source else { return nil }
        return Self(destination: destination, altText: plainText(image), title: image.title)
    }

    nonisolated static func blocks(in source: String) -> [Int: (image: Self, endLine: Int)] {
        guard source.contains("![") else { return [:] }
        var result: [Int: (image: Self, endLine: Int)] = [:]
        for node in Document(parsing: source, options: [.disableSmartOpts]).children {
            guard let image = standalone(in: node), let range = node.range else { continue }
            result[range.lowerBound.line - 1] = (image, range.upperBound.line)
        }
        return result
    }

    nonisolated func localURL(relativeTo documentURL: URL?) throws -> URL {
        guard !destination.isEmpty else { throw MarkdownImageError.invalidPath }
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let base = documentURL?.deletingLastPathComponent() ?? root
        guard let url = URL(string: destination, relativeTo: base)?.absoluteURL,
              url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost"
        else { throw MarkdownImageError.unsupportedLocation }
        if documentURL == nil && !destination.hasPrefix("/") && URL(string: destination)?.scheme == nil {
            throw MarkdownImageError.unsavedDocument
        }
        return url.standardizedFileURL
    }

    nonisolated private static func plainText(_ node: Markup) -> String {
        if let code = node as? InlineCode { return code.code }
        if node.childCount > 0 { return node.children.map(plainText).joined() }
        return (node as? PlainTextConvertibleMarkup)?.plainText ?? ""
    }
}

enum MarkdownImageError: LocalizedError, Equatable {
    case unsavedDocument
    case invalidPath
    case unsupportedLocation
    case unsupportedFormat
    case unreadable
    case invalidAssetsDirectory

    nonisolated var errorDescription: String? {
        switch self {
        case .unsavedDocument: "Save the document to resolve relative image paths."
        case .invalidPath: "The image path is invalid."
        case .unsupportedLocation: "Only local images are supported in this version."
        case .unsupportedFormat: "Only PNG and JPEG images are supported."
        case .unreadable: "The image is missing or could not be read."
        case .invalidAssetsDirectory: "The assets path must be a folder, not a file or symbolic link."
        }
    }
}
