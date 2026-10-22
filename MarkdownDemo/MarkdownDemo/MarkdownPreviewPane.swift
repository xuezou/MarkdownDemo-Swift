#if os(macOS)
import SwiftUI

struct MarkdownPreviewTarget: Equatable {
    let blockID: Int
    let requestID = UUID()

    static func following(blockID: Int, previous: Self?, force: Bool) -> Self {
        if !force, let previous, previous.blockID == blockID { return previous }
        return Self(blockID: blockID)
    }
}

struct MarkdownPreviewPane: View {
    let index: MarkdownDocumentIndex
    let theme: MarkdownTheme
    let target: MarkdownPreviewTarget?
    let navigateToAnchor: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Preview", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.editorHeaderBackground)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(index.blocks) { block in
                            blockContent(block.content)
                                .id(block.id)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: target) { scroll(to: target, using: proxy) }
                .onAppear { scroll(to: target, using: proxy) }
            }
            .background(theme.background)
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.relativeString.hasPrefix("#"), let fragment = url.fragment {
                return navigateToAnchor(fragment) ? .handled : .discarded
            }
            return .systemAction
        })
    }

    private func scroll(to target: MarkdownPreviewTarget?, using proxy: ScrollViewProxy) {
        guard let target else { return }
        proxy.scrollTo(target.blockID, anchor: .top)
    }

    @ViewBuilder private func blockContent(_ block: MarkdownPreviewBlock) -> some View {
        switch block {
        case .markdown(let markdown):
            Text(MarkdownRenderer.render(markdown: markdown, theme: theme))
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .code(let language, let source):
            MarkdownCodeBlockView(language: language, source: source, theme: theme)
        case .mermaid(let source):
            ScrollView(.horizontal) {
                MermaidDiagramView(source: source)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .table(let table):
            ScrollView(.horizontal) {
                MarkdownTableView(table: table, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
#endif
