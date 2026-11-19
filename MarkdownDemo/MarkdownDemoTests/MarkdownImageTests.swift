import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MarkdownDemo

@MainActor
struct MarkdownImageTests {
    @Test func parsesStandaloneImagesAndPreservesSourcePositions() throws {
        let source = "# Title😀\n\n![截图](<assets/中文 image.png> \"Example\")\n\nAfter"
        let blocks = MarkdownPreviewBlockParser.parse(source)
        guard case .image(let image) = blocks[1] else {
            Issue.record("Expected a standalone image block")
            return
        }
        #expect(image.altText == "截图")
        #expect(image.title == "Example")
        let index = MarkdownDocumentIndex(source)
        let offset = (source as NSString).range(of: "![").location
        #expect(index.block(atUTF16Offset: offset)?.content == .image(image))
        #expect(index.headings.map(\.title) == ["Title😀"])
    }

    @Test func codeAndInlineImagesRemainMarkdownOrCode() {
        let source = "```md\n![fake](a.png)\n```\n\nBefore ![inline](a.png) after"
        #expect(MarkdownPreviewBlockParser.parse(source) == [
            .code(language: "md", source: "![fake](a.png)\n"),
            .markdown("Before ![inline](a.png) after")
        ])
    }

    @Test func referenceImagesUseTheirDocumentDefinitions() {
        let source = "![Diagram][image]\n\n[image]: assets/diagram.png"
        let index = MarkdownDocumentIndex(source)
        guard case .image(let image) = index.blocks.first?.content else {
            Issue.record("Expected a resolved reference-style image")
            return
        }
        #expect(image.destination == "assets/diagram.png")
    }

    @Test func relativeURLsDecodeExactlyOnceAndFollowTheDocumentFolder() throws {
        let image = MarkdownImageReference(destination: "assets/%E4%B8%AD%E6%96%87%20%2520.png", altText: "", title: nil)
        let first = URL(fileURLWithPath: "/tmp/first/note.md")
        let second = URL(fileURLWithPath: "/tmp/moved/note.md")
        #expect(try image.localURL(relativeTo: first).path == "/tmp/first/assets/中文 %20.png")
        #expect(try image.localURL(relativeTo: second).path == "/tmp/moved/assets/中文 %20.png")
        let parent = MarkdownImageReference(destination: "../images/a.jpg", altText: "", title: nil)
        #expect(try parent.localURL(relativeTo: first).path == "/tmp/images/a.jpg")
    }

    @Test func relativeImagesNeedASavedDocumentAndNeverLoadNetworkURLs() throws {
        let relative = MarkdownImageReference(destination: "assets/a.png", altText: "", title: nil)
        #expect(throws: MarkdownImageError.unsavedDocument) { try relative.localURL(relativeTo: nil) }
        for destination in ["https://example.com/a.png", "//example.com/a.png", "data:image/png;base64,AAAA"] {
            let image = MarkdownImageReference(destination: destination, altText: "", title: nil)
            #expect(throws: MarkdownImageError.unsupportedLocation) {
                try image.localURL(relativeTo: URL(fileURLWithPath: "/tmp/note.md"))
            }
        }
        let absolute = MarkdownImageReference(destination: "file:///tmp/a.png", altText: "", title: nil)
        #expect(try absolute.localURL(relativeTo: nil).path == "/tmp/a.png")
    }

    @Test func decodesPNGAndJPEGWithoutExpandingLargeImages() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for type in [UTType.png, .jpeg] {
            let url = directory.appendingPathComponent("large.\(type.preferredFilenameExtension!)")
            try ImageTestFiles.writeImage(to: url, type: type, width: 2400, height: 1200)
            let image = try MarkdownLocalImage.load(at: url, maximumPixelSize: 400)
            #expect(image.width == 400)
            #expect(image.height == 200)
        }
    }

    @Test func missingCorruptAndUnsupportedImagesFailCleanly() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: (any Error).self) {
            try MarkdownLocalImage.load(at: directory.appendingPathComponent("missing.png"))
        }
        let broken = directory.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: broken)
        #expect(throws: (any Error).self) { try MarkdownLocalImage.load(at: broken) }
        let gif = directory.appendingPathComponent("animated.gif")
        try ImageTestFiles.writeImage(to: gif, type: .gif)
        #expect(throws: MarkdownImageError.unsupportedFormat) { try MarkdownLocalImage.load(at: gif) }
    }
}

enum ImageTestFiles {
    static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeImage(to url: URL, type: UTType = .png, width: Int = 16, height: Int = 8) throws {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                           bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(output, image, nil)
        #expect(CGImageDestinationFinalize(output))
    }
}
