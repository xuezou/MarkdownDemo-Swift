#if os(macOS)
import SwiftUI

struct MarkdownOutlineView: View {
    let headings: [MarkdownOutlineHeading]
    let selectedID: Int?
    let navigate: (MarkdownOutlineHeading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Outline", systemImage: "list.bullet.indent")
                .font(.headline)
                .padding(.horizontal, 16)
                .frame(height: 41)
            Divider()
            if headings.isEmpty {
                Text("No Headings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(headings) { heading in
                    Button { navigate(heading) } label: {
                        Text(heading.title.isEmpty ? "Untitled" : heading.title)
                            .font(.callout)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, CGFloat(heading.level - 1) * 12)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(heading.title)
                    .listRowBackground(selectedID == heading.id ? Color.accentColor.opacity(0.15) : .clear)
                    .accessibilityIdentifier("outline.heading.\(heading.id)")
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)
        .background(.background)
        .accessibilityIdentifier("editor.outline")
    }
}
#endif
