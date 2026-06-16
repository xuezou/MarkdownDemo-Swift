//
//  MarkdownEditorView.swift
//  MarkdownDemo
//

import SwiftUI

#if os(macOS)
import UniformTypeIdentifiers

struct MarkdownEditorView: View {
    @State private var document = MarkdownEditorDocument()
    @State private var isOpeningFile = false
    @State private var openErrorMessage: String?

    var body: some View {
        NavigationStack {
            HSplitView {
                MarkdownSourcePane(document: document)
                    .frame(minWidth: 320)

                MarkdownPreviewPane(markdown: document.markdown)
                    .frame(minWidth: 320)
            }
            .navigationTitle(documentTitle)
            .toolbar {
                ToolbarItem {
                    Button {
                        isOpeningFile = true
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                    .help("Open Markdown File")
                }

                ToolbarItem {
                    Label(
                        document.isDirty ? "Modified" : "Saved",
                        systemImage: document.isDirty ? "circle.fill" : "checkmark.circle"
                    )
                    .foregroundStyle(document.isDirty ? .orange : .secondary)
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

    private var documentTitle: String {
        document.isDirty ? "\(document.displayName) - Modified" : document.displayName
    }

    private static var openableContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let markdownType = UTType(filenameExtension: "md") {
            types.insert(markdownType, at: 0)
        }
        return types
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
        do {
            guard let url = try result.get().first else { return }
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try document.load(from: url)
        } catch {
            openErrorMessage = error.localizedDescription
        }
    }
}

private struct MarkdownSourcePane: View {
    @Bindable var document: MarkdownEditorDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Source", systemImage: "square.and.pencil")

            TextEditor(text: $document.markdown)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color.editorSourceBackground)
        }
    }
}

private struct MarkdownPreviewPane: View {
    let markdown: String

    private var blocks: [MarkdownPreviewBlock] {
        MarkdownPreviewBlockParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Preview", systemImage: "eye")

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .markdown(let markdown):
                            Text(MarkdownRenderer.render(markdown: markdown))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        case .mermaid(let source):
                            ScrollView(.horizontal) {
                                MermaidFlowchartView(source: source)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        case .table(let table):
                            ScrollView(.horizontal) {
                                MarkdownTableView(table: table)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.9))
        }
    }
}

private struct PaneHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.editorHeaderBackground)
    }
}

private extension Color {
    static var editorHeaderBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    static var editorSourceBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
}

#Preview {
    MarkdownEditorView()
}
#endif
