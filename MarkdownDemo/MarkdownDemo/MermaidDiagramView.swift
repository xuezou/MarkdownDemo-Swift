//
//  MermaidDiagramView.swift
//  MarkdownDemo
//

import SwiftUI

enum MermaidDiagramKind: Equatable {
    case flowchart
    case sequence
}

enum MermaidDiagramParser {
    nonisolated static func kind(for source: String) -> MermaidDiagramKind? {
        if MermaidFlowchartParser.parse(source) != nil {
            return .flowchart
        }
        if MermaidSequenceDiagramParser.parse(source) != nil {
            return .sequence
        }
        return nil
    }
}

struct MermaidDiagramView: View {
    let source: String

    var body: some View {
        if MermaidFlowchartParser.parse(source) != nil {
            MermaidFlowchartView(source: source)
        } else if let sequence = MermaidSequenceDiagramParser.parse(source) {
            MermaidSequenceDiagramView(diagram: sequence)
        } else {
            UnsupportedMermaidDiagramView(source: source)
        }
    }
}

private struct UnsupportedMermaidDiagramView: View {
    let source: String
    @Environment(\.markdownTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unsupported Mermaid diagram", systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(source)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(theme.mermaidBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
