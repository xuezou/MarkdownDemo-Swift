//
//  MermaidFlowchartParser.swift
//  MarkdownDemo
//

import Foundation

struct MermaidFlowchart: Equatable {
    enum Direction: Equatable {
        case topDown
        case leftRight
        case rightLeft
        case bottomTop
    }

    enum NodeShape: Equatable {
        case process
        case decision
        case stadium
        case rounded
    }

    struct Node: Identifiable, Equatable {
        let id: String
        let label: String
        let shape: NodeShape
    }

    struct Edge: Identifiable, Equatable {
        let id: String
        let from: String
        let to: String
        let label: String?
    }

    let direction: Direction
    let nodes: [Node]
    let edges: [Edge]

    func node(id: String) -> Node? {
        nodes.first { $0.id == id }
    }
}

enum MermaidFlowchartParser {
    nonisolated static func parse(_ source: String) -> MermaidFlowchart? {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

        guard let firstLine = lines.first,
              let direction = parseDirection(firstLine)
        else {
            return nil
        }

        var nodesByID: [String: MermaidFlowchart.Node] = [:]
        var nodeOrder: [String] = []
        var edges: [MermaidFlowchart.Edge] = []

        func upsert(_ endpoint: Endpoint) {
            if !nodesByID.keys.contains(endpoint.id) {
                nodeOrder.append(endpoint.id)
            }

            if endpoint.isExplicit {
                nodesByID[endpoint.id] = MermaidFlowchart.Node(
                    id: endpoint.id,
                    label: endpoint.label,
                    shape: endpoint.shape
                )
            } else if !nodesByID.keys.contains(endpoint.id) {
                nodesByID[endpoint.id] = MermaidFlowchart.Node(
                    id: endpoint.id,
                    label: endpoint.id,
                    shape: .process
                )
            }
        }

        for line in lines.dropFirst() {
            if let edgeParts = parseEdge(line) {
                let from = parseEndpoint(edgeParts.from)
                let to = parseEndpoint(edgeParts.to)
                upsert(from)
                upsert(to)
                edges.append(MermaidFlowchart.Edge(
                    id: "\(edges.count)-\(from.id)-\(to.id)",
                    from: from.id,
                    to: to.id,
                    label: edgeParts.label
                ))
            } else {
                let endpoint = parseEndpoint(line)
                upsert(endpoint)
            }
        }

        let orderedNodes = nodeOrder.compactMap { nodesByID[$0] }
        return MermaidFlowchart(direction: direction, nodes: orderedNodes, edges: edges)
    }

    private struct Endpoint {
        let id: String
        let label: String
        let shape: MermaidFlowchart.NodeShape
        let isExplicit: Bool
    }

    private struct EdgeParts {
        let from: String
        let to: String
        let label: String?
    }

    nonisolated private static func parseDirection(_ line: String) -> MermaidFlowchart.Direction? {
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2,
              parts[0].lowercased() == "flowchart" || parts[0].lowercased() == "graph"
        else {
            return nil
        }

        switch parts[1].uppercased() {
        case "TD", "TB":
            return .topDown
        case "LR":
            return .leftRight
        case "RL":
            return .rightLeft
        case "BT":
            return .bottomTop
        default:
            return nil
        }
    }

    nonisolated private static func parseEdge(_ line: String) -> EdgeParts? {
        guard let arrowRange = line.range(of: "-->") else {
            return nil
        }

        let from = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        var remainder = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        var label: String?

        if remainder.hasPrefix("|"),
           let closingIndex = remainder.dropFirst().firstIndex(of: "|") {
            label = String(remainder[remainder.index(after: remainder.startIndex)..<closingIndex])
                .trimmingCharacters(in: .whitespaces)
            remainder = String(remainder[remainder.index(after: closingIndex)...])
                .trimmingCharacters(in: .whitespaces)
        }

        guard !from.isEmpty, !remainder.isEmpty else {
            return nil
        }

        return EdgeParts(from: from, to: remainder, label: label)
    }

    nonisolated private static func parseEndpoint(_ raw: String) -> Endpoint {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = parseID(from: trimmed)
        let suffix = String(trimmed.dropFirst(id.count)).trimmingCharacters(in: .whitespaces)

        guard !suffix.isEmpty else {
            return Endpoint(id: id, label: id, shape: .process, isExplicit: false)
        }

        if let label = extractWrappedLabel(suffix, prefix: "([", suffix: "])") {
            return Endpoint(id: id, label: label, shape: .stadium, isExplicit: true)
        }

        if let label = extractWrappedLabel(suffix, prefix: "{", suffix: "}") {
            return Endpoint(id: id, label: label, shape: .decision, isExplicit: true)
        }

        if let label = extractWrappedLabel(suffix, prefix: "[", suffix: "]") {
            return Endpoint(id: id, label: label, shape: .process, isExplicit: true)
        }

        if let label = extractWrappedLabel(suffix, prefix: "(", suffix: ")") {
            return Endpoint(id: id, label: label, shape: .rounded, isExplicit: true)
        }

        return Endpoint(id: id, label: suffix, shape: .process, isExplicit: true)
    }

    nonisolated private static func parseID(from text: String) -> String {
        var id = ""
        for character in text {
            if character.isLetter || character.isNumber || character == "_" {
                id.append(character)
            } else {
                break
            }
        }
        return id.isEmpty ? text : id
    }

    nonisolated private static func extractWrappedLabel(
        _ text: String,
        prefix: String,
        suffix: String
    ) -> String? {
        guard text.hasPrefix(prefix), text.hasSuffix(suffix) else {
            return nil
        }

        let start = text.index(text.startIndex, offsetBy: prefix.count)
        let end = text.index(text.endIndex, offsetBy: -suffix.count)
        return String(text[start..<end]).trimmingCharacters(in: .whitespaces)
    }
}
