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
    @Environment(\.markdownTheme) private var theme
    @Environment(\.openDocument) private var openDocument

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editorContent
                Divider()
                MarkdownStatisticsBar(markdown: document.markdown)
            }
            .toolbar {
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
                    Button {
                        isOpeningFile = true
                    } label: {
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
    }

    private var previewPane: some View {
        MarkdownPreviewPane(markdown: document.markdown, theme: theme)
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

private struct MarkdownPreviewPane: View {
    let markdown: String
    let theme: MarkdownTheme

    private var blocks: [MarkdownPreviewBlock] {
        MarkdownPreviewBlockParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Preview", systemImage: "eye", theme: theme)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .markdown(let markdown):
                            Text(MarkdownRenderer.render(markdown: markdown, theme: theme))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        case .mermaid(let source):
                            ScrollView(.horizontal) {
                                MermaidDiagramView(source: source)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        case .table(let table):
                            ScrollView(.horizontal) {
                                MarkdownTableView(table: table, theme: theme)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background)
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
