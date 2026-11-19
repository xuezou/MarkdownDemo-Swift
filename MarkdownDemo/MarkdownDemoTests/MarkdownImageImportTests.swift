import CoreGraphics
import Foundation
import Testing
@testable import MarkdownDemo

@MainActor
struct MarkdownImageImportTests {
    @Test func copiesIntoAssetsAndProducesPortableEscapedReferences() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("图 [a] %20 (1).png")
        try ImageTestFiles.writeImage(to: source)
        let note = directory.appendingPathComponent("note.md")
        let imported = try MarkdownImageImporter.copy([source], to: note)
        let result = try #require(imported.first)
        #expect(result.url.deletingLastPathComponent().lastPathComponent == "assets")
        #expect(result.wasCopied)
        let reference = try #require(MarkdownImageReference.blocks(in: result.markdown)[0]?.image)
        #expect(try reference.localURL(relativeTo: note) == result.url)
        #expect(reference.altText == "图 [a] %20 (1)")
        #expect(try Data(contentsOf: result.url) == Data(contentsOf: source))
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func repeatedNamesNeverReplaceExistingFiles() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        let note = directory.appendingPathComponent("note.md")
        let first = try MarkdownImageImporter.copy([source], to: note)
        let second = try MarkdownImageImporter.copy([source], to: note)
        #expect(first[0].url.lastPathComponent == "shot.png")
        #expect(second[0].url.lastPathComponent == "shot-1.png")
        #expect(FileManager.default.fileExists(atPath: first[0].url.path))
    }

    @Test func failedBatchRollsBackOnlyNewCopies() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = directory.appendingPathComponent("valid.png")
        let broken = directory.appendingPathComponent("broken.png")
        try ImageTestFiles.writeImage(to: valid)
        try Data("broken".utf8).write(to: broken)
        let note = directory.appendingPathComponent("note.md")
        let original = try MarkdownImageImporter.copy([valid], to: note)[0]
        #expect(throws: (any Error).self) { try MarkdownImageImporter.copy([valid, broken], to: note) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: original.url.deletingLastPathComponent().path) == ["valid.png"])
    }

    @Test func existingAssetsAreReusedAndNotDeletedByRollback() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        let note = directory.appendingPathComponent("note.md")
        let first = try MarkdownImageImporter.copy([source], to: note)[0]
        let reused = try MarkdownImageImporter.copy([first.url], to: note)
        #expect(reused[0].url == first.url)
        #expect(!reused[0].wasCopied)
        MarkdownImageImporter.discard(reused)
        #expect(FileManager.default.fileExists(atPath: first.url.path))
    }

    @Test func assetsFileAndSymlinkDoNotReceiveWrites() throws {
        let directory = try ImageTestFiles.directory()
        let outside = try ImageTestFiles.directory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: outside)
        }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        let assets = directory.appendingPathComponent("assets")
        let note = directory.appendingPathComponent("note.md")
        try Data("keep".utf8).write(to: assets)
        #expect(throws: (any Error).self) { try MarkdownImageImporter.copy([source], to: note) }
        #expect(try Data(contentsOf: assets) == Data("keep".utf8))
        try FileManager.default.removeItem(at: assets)
        try FileManager.default.createSymbolicLink(at: assets, withDestinationURL: outside)
        #expect(throws: (any Error).self) { try MarkdownImageImporter.copy([source], to: note) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    @Test func cancelledImportsDoNotCreateAnImageReferenceOrCopy() async throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("shot.png")
        try ImageTestFiles.writeImage(to: source)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try MarkdownImageImporter.copy([source], to: directory.appendingPathComponent("note.md"))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("assets").path))
    }

    @Test func importingASymlinkCopiesTheActualImageForPortability() throws {
        let directory = try ImageTestFiles.directory()
        let outside = try ImageTestFiles.directory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: outside)
        }
        let original = outside.appendingPathComponent("original.png")
        try ImageTestFiles.writeImage(to: original)
        let link = directory.appendingPathComponent("linked.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        let imported = try MarkdownImageImporter.copy([link], to: directory.appendingPathComponent("note.md"))[0]
        let attributes = try FileManager.default.attributesOfItem(atPath: imported.url.path)
        #expect(attributes[.type] as? FileAttributeType == .typeRegular)
        try FileManager.default.removeItem(at: original)
        #expect(try MarkdownLocalImage.load(at: imported.url).width == 16)
    }

    @Test func entityLikeFilenamesRemainLiteralInPathsAndAltText() throws {
        let directory = try ImageTestFiles.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("photo&copy; &#x41;.png")
        try ImageTestFiles.writeImage(to: source)
        let note = directory.appendingPathComponent("note.md")
        let imported = try MarkdownImageImporter.copy([source], to: note)[0]
        let reference = try #require(MarkdownImageReference.blocks(in: imported.markdown)[0]?.image)
        #expect(reference.altText == "photo&copy; &#x41;")
        let resolved = try reference.localURL(relativeTo: note)
        #expect(resolved.path == imported.url.path)
        #expect(try MarkdownLocalImage.load(at: resolved).width == 16)
    }
}
