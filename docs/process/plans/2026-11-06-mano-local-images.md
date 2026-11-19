# Mano 0.0.3 Local Images Implementation Plan

> Execute inline with superpowers:executing-plans. Scope approved in chat on 2026-11-06.

**Goal:** Read standalone local PNG/JPEG images and import images into a Markdown document's adjacent assets directory.

**Architecture:** Keep DocumentGroup and NSTextView. Pass the document URL into preview, recognize standalone images using swift-markdown, downsample with ImageIO, and insert references through the native editor's undo system.

**Tech Stack:** SwiftUI, AppKit, Foundation, ImageIO, swift-markdown, Swift Testing.

## Approved Design

- Relative paths resolve from the saved document directory; network loading, SVG, animation and inline image/text layout are deferred.
- Choose or drop PNG/JPEG files; save an untitled document before importing, copy into assets without replacing existing files, and insert relative references at the original selection or drop position.
- Cancellation or failure must not insert a broken reference. Undo removes inserted text but retains imported image files.
- A changed document or selection context during an asynchronous import must not overwrite intervening edits.
- Missing, corrupt and unsupported images show a readable placeholder and retry action. Large images decode as thumbnails off the main thread.
- Save As updates the relative-path base and warns that external image files are not automatically moved.
- iPhone retains the demo list. Shared parsing and preview must compile for iOS; no screenshot/UI automation is requested.

## Approaches

Use the existing parser plus native image/file APIs. A WebView or new image framework adds unnecessary scope for local PNG/JPEG images. Keep file import and decoding independent of the views so their failure paths are testable.

## Tasks

- [x] Read: Add MarkdownImageReference, local URL resolution, ImageIO thumbnail loading, standalone-image parsing and source-index integration. Verify encoded names, reference definitions, code fences, unsupported formats and image failures.
- [x] Write: Add collision-safe assets import, native undo-aware insertion, a toolbar picker and source-editor drop handling. Verify copy rollback, cancellation, changed text, Unicode selection ranges, same-file reuse and undo.
- [x] Integrate: Thread fileURL through DocumentGroup, add image preview states and Save As notice, update documentation, run macOS unit tests and iPhone compilation, then request one independent review.

## Validation

- macOS: xcodebuild test for MarkdownDemoTests only, destination platform=macOS, existing build/DerivedData.
- iOS: tb-build build, existing build/DerivedData; no simulator launch or screenshot suite.
- Gate: no regression in outline, tables, Mermaid, native find/replace or undo. Publication and signing are a separate release step.

## Execution Notes

- Ruling: Continue in the current workspace as requested earlier; do not introduce a worktree, commit or publish during feature implementation.
- Verified: 61 macOS unit tests passed; iPhone build passed; independent review findings reproduced and fixed, with no remaining findings on re-review. SwiftLint is not configured.
- Ruling: Compare exact UTF-16 snapshots before applying a captured selection; preserve literal entity-like filenames in both image paths and alt text; copy resolved image data rather than symbolic links.
- Manual verification remains for native dialogs, drag/drop placement and visual behavior. No screenshot/UI automation was run.
