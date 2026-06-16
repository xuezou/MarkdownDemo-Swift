//
//  MermaidFlowchartLayout.swift
//  MarkdownDemo
//

import CoreGraphics
import Foundation

struct MermaidFlowchartLayout {
    let size: CGSize
    let nodeFrames: [String: CGRect]
    let edgeLabelPoints: [String: CGPoint]
}

enum MermaidFlowchartLayoutEngine {
    nonisolated static func layout(_ flowchart: MermaidFlowchart) -> MermaidFlowchartLayout {
        let depths = nodeDepths(flowchart)
        let levels = Dictionary(grouping: flowchart.nodes) { depths[$0.id] ?? 0 }
        let sortedDepths = levels.keys.sorted()

        switch flowchart.direction {
        case .topDown:
            return verticalLayout(flowchart, levels: levels, sortedDepths: sortedDepths)
        case .bottomTop:
            return verticalLayout(flowchart, levels: levels, sortedDepths: Array(sortedDepths.reversed()))
        case .leftRight:
            return horizontalLayout(flowchart, levels: levels, sortedDepths: sortedDepths)
        case .rightLeft:
            return horizontalLayout(flowchart, levels: levels, sortedDepths: Array(sortedDepths.reversed()))
        }
    }

    nonisolated private static func nodeDepths(_ flowchart: MermaidFlowchart) -> [String: Int] {
        var depths = Dictionary(uniqueKeysWithValues: flowchart.nodes.map { ($0.id, 0) })
        let nodeIDs = Set(flowchart.nodes.map(\.id))

        for _ in 0..<flowchart.nodes.count {
            var changed = false
            for edge in flowchart.edges where nodeIDs.contains(edge.from) && nodeIDs.contains(edge.to) {
                let proposedDepth = (depths[edge.from] ?? 0) + 1
                if proposedDepth > (depths[edge.to] ?? 0) {
                    depths[edge.to] = proposedDepth
                    changed = true
                }
            }
            if !changed { break }
        }

        return depths
    }

    nonisolated private static func verticalLayout(
        _ flowchart: MermaidFlowchart,
        levels: [Int: [MermaidFlowchart.Node]],
        sortedDepths: [Int]
    ) -> MermaidFlowchartLayout {
        let margin: CGFloat = 28
        let columnSpacing: CGFloat = 28
        let rowSpacing: CGFloat = 76
        var frames: [String: CGRect] = [:]
        var y = margin
        var maxWidth: CGFloat = 0

        for depth in sortedDepths {
            let nodes = levels[depth] ?? []
            let sizes = nodes.map(nodeSize)
            let rowWidth = sizes.reduce(CGFloat(0)) { $0 + $1.width }
                + CGFloat(max(nodes.count - 1, 0)) * columnSpacing
            maxWidth = max(maxWidth, rowWidth)
        }

        let canvasWidth = maxWidth + margin * 2
        for depth in sortedDepths {
            let nodes = levels[depth] ?? []
            let sizes = nodes.map(nodeSize)
            let rowWidth = sizes.reduce(CGFloat(0)) { $0 + $1.width }
                + CGFloat(max(nodes.count - 1, 0)) * columnSpacing
            var x = (canvasWidth - rowWidth) / 2
            var rowHeight: CGFloat = 0

            for (index, node) in nodes.enumerated() {
                let size = sizes[index]
                frames[node.id] = CGRect(origin: CGPoint(x: x, y: y), size: size)
                x += size.width + columnSpacing
                rowHeight = max(rowHeight, size.height)
            }

            y += rowHeight + rowSpacing
        }

        let labels = edgeLabelPoints(flowchart.edges, frames: frames)
        return MermaidFlowchartLayout(
            size: CGSize(width: canvasWidth, height: max(y - rowSpacing + margin, 160)),
            nodeFrames: frames,
            edgeLabelPoints: labels
        )
    }

    nonisolated private static func horizontalLayout(
        _ flowchart: MermaidFlowchart,
        levels: [Int: [MermaidFlowchart.Node]],
        sortedDepths: [Int]
    ) -> MermaidFlowchartLayout {
        let margin: CGFloat = 28
        let columnSpacing: CGFloat = 96
        let rowSpacing: CGFloat = 28
        var frames: [String: CGRect] = [:]
        var x = margin
        var maxHeight: CGFloat = 0

        for depth in sortedDepths {
            let nodes = levels[depth] ?? []
            let sizes = nodes.map(nodeSize)
            let columnHeight = sizes.reduce(CGFloat(0)) { $0 + $1.height }
                + CGFloat(max(nodes.count - 1, 0)) * rowSpacing
            maxHeight = max(maxHeight, columnHeight)
        }

        let canvasHeight = max(maxHeight + margin * 2, 160)
        for depth in sortedDepths {
            let nodes = levels[depth] ?? []
            let sizes = nodes.map(nodeSize)
            let columnHeight = sizes.reduce(CGFloat(0)) { $0 + $1.height }
                + CGFloat(max(nodes.count - 1, 0)) * rowSpacing
            var y = (canvasHeight - columnHeight) / 2
            var columnWidth: CGFloat = 0

            for (index, node) in nodes.enumerated() {
                let size = sizes[index]
                frames[node.id] = CGRect(origin: CGPoint(x: x, y: y), size: size)
                y += size.height + rowSpacing
                columnWidth = max(columnWidth, size.width)
            }

            x += columnWidth + columnSpacing
        }

        let labels = edgeLabelPoints(flowchart.edges, frames: frames)
        return MermaidFlowchartLayout(
            size: CGSize(width: max(x - columnSpacing + margin, 240), height: canvasHeight),
            nodeFrames: frames,
            edgeLabelPoints: labels
        )
    }

    nonisolated private static func nodeSize(_ node: MermaidFlowchart.Node) -> CGSize {
        let labelWidth = CGFloat(node.label.count) * 10 + 36
        let width = min(max(labelWidth, 120), 240)
        let height: CGFloat
        switch node.shape {
        case .decision:
            height = 82
        case .process, .stadium, .rounded:
            height = 54
        }
        return CGSize(width: width, height: height)
    }

    nonisolated private static func edgeLabelPoints(
        _ edges: [MermaidFlowchart.Edge],
        frames: [String: CGRect]
    ) -> [String: CGPoint] {
        var points: [String: CGPoint] = [:]
        for edge in edges {
            guard edge.label != nil,
                  let fromFrame = frames[edge.from],
                  let toFrame = frames[edge.to]
            else {
                continue
            }
            points[edge.id] = CGPoint(
                x: (fromFrame.midX + toFrame.midX) / 2,
                y: (fromFrame.midY + toFrame.midY) / 2
            )
        }
        return points
    }
}
