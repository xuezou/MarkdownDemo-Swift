import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MarkdownCodeBlockView: View {
    let language: String
    let source: String
    let theme: MarkdownTheme
    @State private var copied = false
    @State private var copyFailed = false
    @State private var feedbackID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "Code" : language)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: copyCode) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(copied ? "Copied" : "Copy Code")
                .accessibilityLabel(copied ? "Copied" : "Copy Code")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.white.opacity(0.06))
            ScrollView(.horizontal) {
                Text(verbatim: source)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(16)
            }
        }
        .foregroundStyle(theme.codeText)
        .background(theme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(theme.codeText.opacity(0.16), lineWidth: 1)
        }
        .task(id: feedbackID) {
            guard copied else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                copied = false
            } catch { }
        }
        .onChange(of: source) {
            copied = false
            feedbackID = UUID()
        }
        .alert("Could Not Copy Code", isPresented: $copyFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func copyCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(source, forType: .string)
        copyFailed = !copied
        #else
        UIPasteboard.general.string = source
        copied = true
        #endif
        feedbackID = UUID()
    }
}
