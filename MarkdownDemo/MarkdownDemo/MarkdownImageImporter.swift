import Foundation

struct MarkdownImportedImage: Sendable {
    let url: URL
    let markdown: String
    let wasCopied: Bool
}

enum MarkdownImageImporter {
    nonisolated static func copy(_ sources: [URL], to documentURL: URL) throws -> [MarkdownImportedImage] {
        try Task.checkCancellation()
        guard !sources.isEmpty else { return [] }
        guard documentURL.isFileURL else { throw MarkdownImageError.invalidPath }
        let folder = documentURL.deletingLastPathComponent().resolvingSymlinksInPath()
        let assets = folder.appendingPathComponent("assets", isDirectory: true)
        var imported: [MarkdownImportedImage] = []
        do {
            for source in sources {
                try Task.checkCancellation()
                imported.append(try copyOne(source, into: assets))
            }
            try Task.checkCancellation()
            return imported
        } catch {
            discard(imported)
            throw error
        }
    }

    nonisolated static func discard(_ images: [MarkdownImportedImage]) {
        for image in images where image.wasCopied {
            try? FileManager.default.removeItem(at: image.url)
        }
    }

    nonisolated private static func copyOne(_ source: URL, into assets: URL) throws -> MarkdownImportedImage {
        guard source.isFileURL, ["png", "jpg", "jpeg"].contains(source.pathExtension.lowercased())
        else { throw MarkdownImageError.unsupportedFormat }
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        _ = try MarkdownLocalImage.load(at: source, maximumPixelSize: 64)
        let manager = FileManager.default
        if manager.fileExists(atPath: assets.path) {
            let attributes = try manager.attributesOfItem(atPath: assets.path)
            guard attributes[.type] as? FileAttributeType == .typeDirectory
            else { throw MarkdownImageError.invalidAssetsDirectory }
        } else {
            try manager.createDirectory(at: assets, withIntermediateDirectories: false)
        }
        let resolved = source.resolvingSymlinksInPath()
        if resolved.deletingLastPathComponent() == assets {
            return importedImage(at: resolved, wasCopied: false)
        }
        var suffix = 0
        while true {
            try Task.checkCancellation()
            let stem = source.deletingPathExtension().lastPathComponent
            let name = suffix == 0 ? source.lastPathComponent : "\(stem)-\(suffix).\(source.pathExtension)"
            let destination = assets.appendingPathComponent(name)
            do {
                try manager.copyItem(at: resolved, to: destination)
                return importedImage(at: destination, wasCopied: true)
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                suffix += 1
            }
        }
    }

    nonisolated private static func importedImage(at url: URL, wasCopied: Bool) -> MarkdownImportedImage {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "?#%&()[]<>\\")
        let path = ("assets/" + url.lastPathComponent).addingPercentEncoding(withAllowedCharacters: allowed)
            ?? "assets/" + url.lastPathComponent
        let altText = url.deletingPathExtension().lastPathComponent.map { character -> String in
            if character.isNewline { return " " }
            return "\\`*_{}[]<>()#!|~&".contains(character) ? "\\\(character)" : String(character)
        }.joined()
        return MarkdownImportedImage(url: url, markdown: "![\(altText)](\(path))", wasCopied: wasCopied)
    }
}
