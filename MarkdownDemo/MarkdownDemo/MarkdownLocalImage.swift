import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MarkdownLocalImage {
    nonisolated static func load(at url: URL, maximumPixelSize: Int = 2048) throws -> CGImage {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { throw MarkdownImageError.unreadable }
        guard let type = CGImageSourceGetType(source),
              [UTType.png.identifier, UTType.jpeg.identifier].contains(type as String)
        else { throw MarkdownImageError.unsupportedFormat }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maximumPixelSize),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw MarkdownImageError.unreadable }
        return image
    }
}
