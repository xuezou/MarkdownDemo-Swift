//
//  MermaidSequenceDiagramParser.swift
//  MarkdownDemo
//

import Foundation

struct MermaidSequenceDiagram: Equatable {
    struct Participant: Identifiable, Equatable {
        let id: String
        let displayName: String
    }

    enum MessageStyle: Equatable {
        case solid
        case dashed
    }

    struct Message: Identifiable, Equatable {
        let id: String
        let from: String
        let to: String
        let text: String
        let style: MessageStyle
    }

    enum GroupKind: Equatable {
        case alt
        case opt
    }

    enum Statement: Equatable {
        case message(Message)
        case groupStart(kind: GroupKind, title: String)
        case groupElse(title: String)
        case groupEnd
    }

    let participants: [Participant]
    let statements: [Statement]

    var messages: [Message] {
        statements.compactMap { statement in
            if case .message(let message) = statement {
                return message
            }
            return nil
        }
    }

    func participant(id: String) -> Participant? {
        participants.first { $0.id == id }
    }
}

enum MermaidSequenceDiagramParser {
    nonisolated static func parse(_ source: String) -> MermaidSequenceDiagram? {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

        guard lines.first?.lowercased() == "sequencediagram" else {
            return nil
        }

        var participantsByID: [String: MermaidSequenceDiagram.Participant] = [:]
        var participantOrder: [String] = []
        var statements: [MermaidSequenceDiagram.Statement] = []

        func upsertParticipant(id: String, displayName: String? = nil) {
            if !participantsByID.keys.contains(id) {
                participantOrder.append(id)
            }

            if let displayName {
                participantsByID[id] = MermaidSequenceDiagram.Participant(id: id, displayName: displayName)
            } else if !participantsByID.keys.contains(id) {
                participantsByID[id] = MermaidSequenceDiagram.Participant(id: id, displayName: id)
            }
        }

        for line in lines.dropFirst() {
            if let participant = parseParticipant(line) {
                upsertParticipant(id: participant.id, displayName: participant.displayName)
            } else if let group = parseGroupStatement(line) {
                statements.append(group)
            } else if let message = parseMessage(line, index: statements.count) {
                upsertParticipant(id: message.from)
                upsertParticipant(id: message.to)
                statements.append(.message(message))
            }
        }

        let participants = participantOrder.compactMap { participantsByID[$0] }
        guard !participants.isEmpty, !statements.isEmpty else {
            return nil
        }

        return MermaidSequenceDiagram(participants: participants, statements: statements)
    }

    nonisolated private static func parseParticipant(_ line: String) -> MermaidSequenceDiagram.Participant? {
        let prefix = "participant "
        guard line.lowercased().hasPrefix(prefix) else {
            return nil
        }

        let content = String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else {
            return nil
        }

        if let aliasRange = content.range(of: " as ", options: [.caseInsensitive]) {
            let id = String(content[..<aliasRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let displayName = String(content[aliasRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty, !displayName.isEmpty else {
                return nil
            }
            return MermaidSequenceDiagram.Participant(id: id, displayName: displayName)
        }

        let id = content.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? content
        return MermaidSequenceDiagram.Participant(id: id, displayName: id)
    }

    nonisolated private static func parseGroupStatement(_ line: String) -> MermaidSequenceDiagram.Statement? {
        if let title = title(after: "alt ", in: line) {
            return .groupStart(kind: .alt, title: title)
        }
        if let title = title(after: "opt ", in: line) {
            return .groupStart(kind: .opt, title: title)
        }
        if let title = title(after: "else ", in: line) {
            return .groupElse(title: title)
        }
        if line.lowercased() == "end" {
            return .groupEnd
        }
        return nil
    }

    nonisolated private static func parseMessage(
        _ line: String,
        index: Int
    ) -> MermaidSequenceDiagram.Message? {
        let operators: [(token: String, style: MermaidSequenceDiagram.MessageStyle)] = [
            ("-->>", .dashed),
            ("->>", .solid)
        ]

        for item in operators {
            guard let operatorRange = line.range(of: item.token) else {
                continue
            }

            let from = String(line[..<operatorRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let remainder = String(line[operatorRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            let parts = remainder.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard !from.isEmpty, let toPart = parts.first else {
                return nil
            }

            let to = String(toPart).trimmingCharacters(in: .whitespaces)
            guard !to.isEmpty else {
                return nil
            }

            let text = parts.count > 1
                ? String(parts[1]).trimmingCharacters(in: .whitespaces)
                : ""

            return MermaidSequenceDiagram.Message(
                id: "\(index)-\(from)-\(to)",
                from: from,
                to: to,
                text: text,
                style: item.style
            )
        }

        return nil
    }

    nonisolated private static func title(after prefix: String, in line: String) -> String? {
        guard line.lowercased().hasPrefix(prefix) else {
            return nil
        }
        return String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespaces)
    }
}
