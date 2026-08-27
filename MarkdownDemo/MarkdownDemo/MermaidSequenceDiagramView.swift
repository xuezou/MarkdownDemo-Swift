//
//  MermaidSequenceDiagramView.swift
//  MarkdownDemo
//

import SwiftUI

struct MermaidSequenceDiagramView: View {
    let diagram: MermaidSequenceDiagram
    @Environment(\.markdownTheme) private var theme

    private var layout: SequenceDiagramLayout {
        SequenceDiagramLayout(diagram: diagram)
    }

    var body: some View {
        let layout = layout

        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawLifelines(context: context, layout: layout)
                drawMessages(context: context, layout: layout)
            }

            ForEach(Array(diagram.participants.enumerated()), id: \.element.id) { index, participant in
                SequenceParticipantHeader(participant: participant, theme: theme)
                    .frame(width: layout.participantWidth)
                    .position(x: layout.xPosition(forParticipantAt: index), y: 26)
            }

            ForEach(Array(diagram.statements.enumerated()), id: \.offset) { index, statement in
                switch statement {
                case .message(let message):
                    SequenceMessageLabel(message: message, theme: theme)
                        .frame(maxWidth: layout.messageLabelWidth(for: message), alignment: .center)
                        .position(layout.messageLabelPosition(for: message, at: index))
                case .groupStart(let kind, let title):
                    SequenceGroupLabel(title: "\(kind.label): \(title)", theme: theme)
                        .position(x: layout.size.width / 2, y: layout.yPosition(forStatementAt: index))
                case .groupElse(let title):
                    SequenceGroupLabel(title: "else: \(title)", theme: theme)
                        .position(x: layout.size.width / 2, y: layout.yPosition(forStatementAt: index))
                case .groupEnd:
                    EmptyView()
                }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .padding(16)
        .background(theme.mermaidBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.tableBorder, lineWidth: 1)
        }
    }

    private func drawLifelines(context: GraphicsContext, layout: SequenceDiagramLayout) {
        var lineStyle = StrokeStyle(lineWidth: 1, dash: [5, 6])
        lineStyle.lineCap = .round

        for index in diagram.participants.indices {
            let x = layout.xPosition(forParticipantAt: index)
            var path = Path()
            path.move(to: CGPoint(x: x, y: layout.lifelineTop))
            path.addLine(to: CGPoint(x: x, y: layout.lifelineBottom))
            context.stroke(path, with: .color(theme.tableBorder), style: lineStyle)
        }
    }

    private func drawMessages(context: GraphicsContext, layout: SequenceDiagramLayout) {
        for (index, statement) in diagram.statements.enumerated() {
            switch statement {
            case .message(let message):
                drawMessage(message, at: index, context: context, layout: layout)
            case .groupStart, .groupElse:
                drawGroupBand(at: index, context: context, layout: layout)
            case .groupEnd:
                drawGroupEnd(at: index, context: context, layout: layout)
            }
        }
    }

    private func drawMessage(
        _ message: MermaidSequenceDiagram.Message,
        at index: Int,
        context: GraphicsContext,
        layout: SequenceDiagramLayout
    ) {
        guard let fromIndex = layout.participantIndex(message.from),
              let toIndex = layout.participantIndex(message.to)
        else {
            return
        }

        let y = layout.yPosition(forStatementAt: index)
        let fromX = layout.xPosition(forParticipantAt: fromIndex)
        let toX = layout.xPosition(forParticipantAt: toIndex)
        let style = StrokeStyle(
            lineWidth: 1.6,
            dash: message.style == .dashed ? [6, 5] : []
        )

        if fromIndex == toIndex {
            drawSelfMessage(at: CGPoint(x: fromX, y: y), context: context, strokeStyle: style)
            return
        }

        var path = Path()
        path.move(to: CGPoint(x: fromX, y: y))
        path.addLine(to: CGPoint(x: toX, y: y))
        context.stroke(path, with: .color(theme.link), style: style)
        drawArrow(context: context, from: CGPoint(x: fromX, y: y), to: CGPoint(x: toX, y: y))
    }

    private func drawSelfMessage(
        at point: CGPoint,
        context: GraphicsContext,
        strokeStyle: StrokeStyle
    ) {
        let width: CGFloat = 52
        let height: CGFloat = 28
        var path = Path()
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x + width, y: point.y))
        path.addLine(to: CGPoint(x: point.x + width, y: point.y + height))
        path.addLine(to: CGPoint(x: point.x, y: point.y + height))
        context.stroke(path, with: .color(theme.link), style: strokeStyle)
        drawArrow(
            context: context,
            from: CGPoint(x: point.x + width, y: point.y + height),
            to: CGPoint(x: point.x, y: point.y + height)
        )
    }

    private func drawGroupBand(
        at index: Int,
        context: GraphicsContext,
        layout: SequenceDiagramLayout
    ) {
        let y = layout.yPosition(forStatementAt: index)
        let rect = CGRect(x: 12, y: y - 17, width: layout.size.width - 24, height: 34)
        context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(theme.tableHeaderBackground))
        context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(theme.tableBorder), lineWidth: 1)
    }

    private func drawGroupEnd(
        at index: Int,
        context: GraphicsContext,
        layout: SequenceDiagramLayout
    ) {
        let y = layout.yPosition(forStatementAt: index)
        var path = Path()
        path.move(to: CGPoint(x: 12, y: y))
        path.addLine(to: CGPoint(x: layout.size.width - 12, y: y))
        context.stroke(path, with: .color(theme.tableBorder), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let length: CGFloat = 8
        let spread: CGFloat = .pi / 7
        let pointA = CGPoint(
            x: to.x - length * cos(angle - spread),
            y: to.y - length * sin(angle - spread)
        )
        let pointB = CGPoint(
            x: to.x - length * cos(angle + spread),
            y: to.y - length * sin(angle + spread)
        )

        var path = Path()
        path.move(to: to)
        path.addLine(to: pointA)
        path.addLine(to: pointB)
        path.closeSubpath()
        context.fill(path, with: .color(theme.link))
    }
}

private struct SequenceDiagramLayout {
    let diagram: MermaidSequenceDiagram
    let participantWidth: CGFloat = 128
    let participantSpacing: CGFloat = 96
    let rowHeight: CGFloat = 56
    let topPadding: CGFloat = 68
    let bottomPadding: CGFloat = 24
    let sidePadding: CGFloat = 32

    var size: CGSize {
        CGSize(
            width: max(
                320,
                sidePadding * 2
                    + CGFloat(diagram.participants.count) * participantWidth
                    + CGFloat(max(diagram.participants.count - 1, 0)) * participantSpacing
            ),
            height: topPadding + CGFloat(diagram.statements.count) * rowHeight + bottomPadding
        )
    }

    var lifelineTop: CGFloat {
        52
    }

    var lifelineBottom: CGFloat {
        size.height - 12
    }

    func participantIndex(_ id: String) -> Int? {
        diagram.participants.firstIndex { $0.id == id }
    }

    func xPosition(forParticipantAt index: Int) -> CGFloat {
        sidePadding + participantWidth / 2 + CGFloat(index) * (participantWidth + participantSpacing)
    }

    func yPosition(forStatementAt index: Int) -> CGFloat {
        topPadding + CGFloat(index) * rowHeight + rowHeight / 2
    }

    func messageLabelWidth(for message: MermaidSequenceDiagram.Message) -> CGFloat {
        if message.from == message.to {
            return 140
        }
        guard let fromIndex = participantIndex(message.from),
              let toIndex = participantIndex(message.to)
        else {
            return 160
        }
        let distance = abs(xPosition(forParticipantAt: fromIndex) - xPosition(forParticipantAt: toIndex))
        return max(120, min(distance - 16, 260))
    }

    func messageLabelPosition(
        for message: MermaidSequenceDiagram.Message,
        at index: Int
    ) -> CGPoint {
        let y = yPosition(forStatementAt: index) - 13
        guard let fromIndex = participantIndex(message.from),
              let toIndex = participantIndex(message.to)
        else {
            return CGPoint(x: size.width / 2, y: y)
        }

        let fromX = xPosition(forParticipantAt: fromIndex)
        let toX = xPosition(forParticipantAt: toIndex)
        if fromIndex == toIndex {
            return CGPoint(x: fromX + 74, y: y)
        }
        return CGPoint(x: (fromX + toX) / 2, y: y)
    }
}

private struct SequenceParticipantHeader: View {
    let participant: MermaidSequenceDiagram.Participant
    let theme: MarkdownTheme

    var body: some View {
        Text(participant.displayName)
            .font(.misans(.semibold, size: 13))
            .foregroundStyle(theme.text)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.76)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(theme.tableHeaderBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.tableBorder, lineWidth: 1)
            }
    }
}

private struct SequenceMessageLabel: View {
    let message: MermaidSequenceDiagram.Message
    let theme: MarkdownTheme

    var body: some View {
        Text(message.text.isEmpty ? " " : message.text)
            .font(.misans(.medium, size: 12))
            .foregroundStyle(theme.text)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(theme.mermaidBackground, in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct SequenceGroupLabel: View {
    let title: String
    let theme: MarkdownTheme

    var body: some View {
        Text(title)
            .font(.misans(.semibold, size: 12))
            .foregroundStyle(theme.mermaidHint)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.mermaidBackground, in: Capsule())
    }
}

private extension MermaidSequenceDiagram.GroupKind {
    var label: String {
        switch self {
        case .alt:
            return "alt"
        case .opt:
            return "opt"
        }
    }
}

#Preview {
    MermaidSequenceDiagramView(
        diagram: MermaidSequenceDiagramParser.parse("""
        sequenceDiagram
            participant U as 用户
            participant APP
            participant D as DIAL / PHI
            participant API as 后端
            U->>APP: 扫码
            APP->>D: stat.device + sys.bind
            D-->>APP: 凭证写入成功
            alt 自动日期时间开启
                APP->>D: sys.time.sync
            else 自动日期时间关闭
                APP->>APP: 不自动覆盖 PHI 时间
            end
        """)!
    )
    .padding()
    .markdownTheme(.light)
}
