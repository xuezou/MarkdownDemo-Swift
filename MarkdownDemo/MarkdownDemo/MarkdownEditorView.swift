//
//  MarkdownEditorView.swift
//  MarkdownDemo
//

import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

struct MarkdownEditorView: View {
    @Binding var document: MarkdownEditorDocument
    @State private var isOpeningFile = false
    @State private var openErrorMessage: String?
    @State private var mode = EditorMode.split
    @StateObject private var editor = MarkdownNativeEditorController()
    @AppStorage("editor.darkPreview") private var darkPreview = false
    @AppStorage("editor.showOutline") private var showOutline = true
    @AppStorage("editor.followSelection") private var followSelection = true
    @State private var documentIndex: MarkdownDocumentIndex
    @State private var previewTarget: MarkdownPreviewTarget?
    @State private var sourceOffset = 0
    private var theme: MarkdownTheme { darkPreview ? .dark : .light }
    @Environment(\.openDocument) private var openDocument

    init(document: Binding<MarkdownEditorDocument>) {
        _document = document
        _documentIndex = State(initialValue: MarkdownDocumentIndex(document.wrappedValue.markdown))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if showOutline {
                        MarkdownOutlineView(
                            headings: documentIndex.headings,
                            selectedID: documentIndex.heading(atUTF16Offset: sourceOffset)?.id,
                            navigate: navigate
                        )
                        Divider()
                    }
                    editorContent
                }
                Divider()
                MarkdownStatisticsBar(markdown: document.markdown)
            }
            .toolbar {
                navigationToolbar
                documentToolbar
            }
            .fileImporter(
                isPresented: $isOpeningFile,
                allowedContentTypes: MarkdownEditorView.openableContentTypes,
                allowsMultipleSelection: false,
                onCompletion: openFile
            )
            .alert("Could Not Open File", isPresented: openErrorBinding) {
                Button("OK", role: .cancel) {
                    openErrorMessage = nil
                }
            } message: {
                Text(openErrorMessage ?? "The selected file could not be opened.")
            }
            .onChange(of: document.markdown) {
                documentIndex = MarkdownDocumentIndex(document.markdown)
                updatePreviewPosition()
            }
            .onChange(of: editor.selectionLocation) {
                sourceOffset = editor.selectionLocation
                updatePreviewPosition()
            }
            .onChange(of: followSelection) { updatePreviewPosition(force: true) }
            .onChange(of: mode) { updatePreviewPosition(force: true) }
        }
        .frame(minWidth: 760, minHeight: 360)
    }

    @ToolbarContentBuilder private var navigationToolbar: some ToolbarContent {
        ToolbarItem {
            Toggle(isOn: $showOutline) {
                Label("Outline", systemImage: "sidebar.left")
            }
            .toggleStyle(.button)
            .help(showOutline ? "Hide Outline" : "Show Outline")
            .accessibilityIdentifier("editor.toggleOutline")
        }
        ToolbarItem {
            Toggle(isOn: $followSelection) {
                Label("Follow Editing Position", systemImage: "link")
            }
            .toggleStyle(.button)
            .help(followSelection ? "Stop Following Editing Position" : "Follow Editing Position")
            .accessibilityIdentifier("editor.followSelection")
        }
        ToolbarItem {
            Button { darkPreview.toggle() } label: {
                Label("Preview Appearance", systemImage: darkPreview ? "sun.max" : "moon")
            }
            .help(darkPreview ? "Use Light Preview" : "Use Dark Preview")
        }
        ToolbarItem {
            Picker("Editor Mode", selection: $mode) {
                Label("Edit", systemImage: "square.and.pencil").tag(EditorMode.edit)
                Label("Split", systemImage: "rectangle.split.2x1").tag(EditorMode.split)
                Label("Read", systemImage: "book").tag(EditorMode.read)
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Edit / Split / Read")
            .accessibilityIdentifier("editor.mode")
        }
    }

    @ToolbarContentBuilder private var documentToolbar: some ToolbarContent {
        ToolbarItem {
            Button { showFind(replace: false) } label: {
                Label("Find", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .help("Find")
        }
        ToolbarItem {
            Button { showFind(replace: true) } label: {
                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .help("Find and Replace")
        }
        ToolbarItem {
            Button { isOpeningFile = true } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open Markdown File")
        }
        ToolbarItem {
            Button(action: saveDocument) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save Markdown File")
        }
    }

    @ViewBuilder private var editorContent: some View {
        switch mode {
        case .split:
            HSplitView {
                sourcePane.frame(minWidth: 280)
                previewPane.frame(minWidth: 280)
            }
        case .edit:
            sourcePane
        case .read:
            previewPane
        }
    }

    private var sourcePane: some View {
        MarkdownSourcePane(markdown: $document.markdown, editor: editor)
            .markdownTheme(.dark)
            .environment(\.colorScheme, .dark)
    }

    private var previewPane: some View {
        MarkdownPreviewPane(index: documentIndex, theme: theme, target: previewTarget) { anchor in
            guard let heading = documentIndex.heading(forAnchor: anchor) else { return false }
            navigate(heading)
            return true
        }
            .markdownTheme(theme)
            .environment(\.colorScheme, darkPreview ? .dark : .light)
    }

    private func navigate(_ heading: MarkdownOutlineHeading) {
        sourceOffset = heading.id
        previewTarget = MarkdownPreviewTarget(blockID: heading.blockID)
        editor.navigate(toUTF16Offset: heading.id, focus: mode != .read)
    }

    private func updatePreviewPosition(force: Bool = false) {
        guard followSelection, mode == .split,
              let block = documentIndex.block(atUTF16Offset: sourceOffset) else { return }
        previewTarget = .following(blockID: block.id, previous: previewTarget, force: force)
    }

    private func showFind(replace: Bool) {
        if mode == .read { mode = .split }
        editor.find(replace: replace)
    }

    private static var openableContentTypes: [UTType] {
        MarkdownEditorDocument.readableContentTypes
    }

    private var openErrorBinding: Binding<Bool> {
        Binding(
            get: { openErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    openErrorMessage = nil
                }
            }
        )
    }

    private func openFile(_ result: Result<[URL], Error>) {
        Task { @MainActor in
            do {
                guard let url = try result.get().first else { return }
                try await openDocument(at: url)
            } catch {
                openErrorMessage = error.localizedDescription
            }
        }
    }

    private func saveDocument() {
        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
    }
}

private struct MarkdownSourcePane: View {
    @Binding var markdown: String
    let editor: MarkdownNativeEditorController
    @Environment(\.markdownTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Source", systemImage: "square.and.pencil", theme: theme)

            MarkdownNativeEditor(text: $markdown, controller: editor, theme: theme)
        }
    }
}

private enum EditorMode: Hashable {
    case edit, split, read
}

private struct MarkdownStatisticsBar: View {
    let markdown: String
    @State private var statistics = MarkdownTextStatistics("")

    var body: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            Text("\(statistics.words) words")
            Text("\(statistics.characters) characters")
            Text("\(statistics.lines) lines")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .accessibilityIdentifier("editor.statistics")
        .task(id: markdown) {
            do {
                try await Task.sleep(for: .milliseconds(150))
                statistics = MarkdownTextStatistics(markdown)
            } catch { }
        }
    }
}

private struct PaneHeader: View {
    let title: String
    let systemImage: String
    var theme: MarkdownTheme = .light

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.editorHeaderBackground)
    }
}

#Preview {
    MarkdownEditorView(document: .constant(MarkdownEditorDocument()))
}
#endif
