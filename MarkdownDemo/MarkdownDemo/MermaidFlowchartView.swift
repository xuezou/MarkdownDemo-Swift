//
//  MermaidFlowchartView.swift
//  MarkdownDemo
//

import SwiftUI

struct MermaidFlowchartView: View {
    let source: String

    var body: some View {
        if let flowchart = MermaidFlowchartParser.parse(source) {
            MermaidFlowchartCanvas(flowchart: flowchart)
        } else {
            MermaidFlowchartFallbackView(source: source)
        }
    }
}

private struct MermaidFlowchartCanvas: View {
    let flowchart: MermaidFlowchart

    private var layout: MermaidFlowchartLayout {
        MermaidFlowchartLayoutEngine.layout(flowchart)
    }

    var body: some View {
        let layout = layout

        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawEdges(context: context, layout: layout)
            }

            ForEach(flowchart.edges) { edge in
                if let label = edge.label,
                   let point = layout.edgeLabelPoints[edge.id] {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .position(point)
                }
            }

            ForEach(flowchart.nodes) { node in
                if let frame = layout.nodeFrames[node.id] {
                    MermaidNodeView(node: node)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .padding(16)
        .background(Color.flowchartBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.flowchartStroke.opacity(0.4), lineWidth: 1)
        }
    }

    private func drawEdges(context: GraphicsContext, layout: MermaidFlowchartLayout) {
        for edge in flowchart.edges {
            guard let fromFrame = layout.nodeFrames[edge.from],
                  let toFrame = layout.nodeFrames[edge.to]
            else {
                continue
            }

            let points = edgePoints(from: fromFrame, to: toFrame)
            var path = Path()
            path.move(to: points.start)
            path.addLine(to: points.midA)
            path.addLine(to: points.midB)
            path.addLine(to: points.end)

            context.stroke(path, with: .color(.flowchartStroke), lineWidth: 1.6)
            drawArrow(context: context, from: points.midB, to: points.end)
        }
    }

    private func edgePoints(from fromFrame: CGRect, to toFrame: CGRect) -> (start: CGPoint, midA: CGPoint, midB: CGPoint, end: CGPoint) {
        let isMostlyVertical = abs(fromFrame.midY - toFrame.midY) >= abs(fromFrame.midX - toFrame.midX)

        if isMostlyVertical {
            let sourceIsAbove = fromFrame.midY <= toFrame.midY
            let start = CGPoint(x: fromFrame.midX, y: sourceIsAbove ? fromFrame.maxY : fromFrame.minY)
            let end = CGPoint(x: toFrame.midX, y: sourceIsAbove ? toFrame.minY : toFrame.maxY)
            let midY = (start.y + end.y) / 2
            return (
                start,
                CGPoint(x: start.x, y: midY),
                CGPoint(x: end.x, y: midY),
                end
            )
        } else {
            let sourceIsLeft = fromFrame.midX <= toFrame.midX
            let start = CGPoint(x: sourceIsLeft ? fromFrame.maxX : fromFrame.minX, y: fromFrame.midY)
            let end = CGPoint(x: sourceIsLeft ? toFrame.minX : toFrame.maxX, y: toFrame.midY)
            let midX = (start.x + end.x) / 2
            return (
                start,
                CGPoint(x: midX, y: start.y),
                CGPoint(x: midX, y: end.y),
                end
            )
        }
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let length: CGFloat = 9
        let spread: CGFloat = .pi / 7

        let pointA = CGPoint(
            x: to.x - length * cos(angle - spread),
            y: to.y - length * sin(angle - spread)
        )
        let pointB = CGPoint(
            x: to.x - length * cos(angle + spread),
            y: to.y - length * sin(angle + spread)
        )

        var arrow = Path()
        arrow.move(to: to)
        arrow.addLine(to: pointA)
        arrow.addLine(to: pointB)
        arrow.closeSubpath()

        context.fill(arrow, with: .color(.flowchartStroke))
    }
}

private struct MermaidNodeView: View {
    let node: MermaidFlowchart.Node

    var body: some View {
        ZStack {
            nodeShape

            Text(node.label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, node.shape == .decision ? 20 : 12)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var nodeShape: some View {
        switch node.shape {
        case .process:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.flowchartNodeFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.flowchartNodeStroke, lineWidth: 1.2)
                }
        case .decision:
            DiamondShape()
                .fill(Color.flowchartDecisionFill)
                .overlay {
                    DiamondShape()
                        .stroke(Color.flowchartNodeStroke, lineWidth: 1.2)
                }
        case .stadium:
            Capsule()
                .fill(Color.flowchartTerminalFill)
                .overlay {
                    Capsule()
                        .stroke(Color.flowchartNodeStroke, lineWidth: 1.2)
                }
        case .rounded:
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.flowchartNodeFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.flowchartNodeStroke, lineWidth: 1.2)
                }
        }
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct MermaidFlowchartFallbackView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unsupported Mermaid flowchart", systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(source)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.flowchartBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.flowchartStroke.opacity(0.4), lineWidth: 1)
        }
    }
}

private extension Color {
    static var flowchartBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }

    static var flowchartStroke: Color {
        Color.blue.opacity(0.65)
    }

    static var flowchartNodeStroke: Color {
        Color.blue.opacity(0.5)
    }

    static var flowchartNodeFill: Color {
        Color.blue.opacity(0.14)
    }

    static var flowchartDecisionFill: Color {
        Color.orange.opacity(0.16)
    }

    static var flowchartTerminalFill: Color {
        Color.green.opacity(0.14)
    }
}

#Preview {
    MermaidFlowchartView(source: """
    flowchart TD
        A([路线标签管理]) --> B{标签类型}
        B -->|系统标签| C[Saved / Liked 不可删改]
        B -->|自定义标签| D{用户操作}
        D -->|创建| E[创建标签]
        D -->|重命名| F[更新标签名]
        D -->|删除| G[删除标签]
        G --> H[关联路线回到 Saved]
        C --> I([完成])
        E --> I
        F --> I
        H --> I
    """)
    .padding()
}
