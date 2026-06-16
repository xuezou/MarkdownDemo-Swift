//
//  MarkdownTableView.swift
//  MarkdownDemo
//

import SwiftUI

struct MarkdownTableView: View {
    let table: MarkdownTable

    private var columnWidths: [CGFloat] {
        table.headers.indices.map { index in
            let values = [table.headers[index]] + table.rows.compactMap { row in
                index < row.count ? row[index] : nil
            }
            let widest = values.map(displayWidth).max() ?? 0
            return min(max(CGFloat(widest) * 7.5 + 32, 96), 360)
        }
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(table.headers.indices, id: \.self) { index in
                    MarkdownTableCell(
                        text: table.headers[index],
                        width: columnWidths[index],
                        alignment: alignment(at: index),
                        isHeader: true
                    )
                }
            }

            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(table.headers.indices, id: \.self) { columnIndex in
                        MarkdownTableCell(
                            text: columnIndex < row.count ? row[columnIndex] : "",
                            width: columnWidths[columnIndex],
                            alignment: alignment(at: columnIndex),
                            isHeader: false,
                            isAlternateRow: rowIndex.isMultiple(of: 2)
                        )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.markdownTableBorder, lineWidth: 1)
        }
    }

    private func alignment(at index: Int) -> MarkdownTable.Alignment {
        index < table.alignments.count ? table.alignments[index] : .left
    }

    private func displayWidth(_ text: String) -> Int {
        text.reduce(0) { width, character in
            width + (character.isASCII ? 1 : 2)
        }
    }
}

private struct MarkdownTableCell: View {
    let text: String
    let width: CGFloat
    let alignment: MarkdownTable.Alignment
    let isHeader: Bool
    var isAlternateRow = false

    var body: some View {
        Text(MarkdownRenderer.render(markdown: text))
            .font(isHeader ? .misans(.semibold, size: 14) : .misans(.medium, size: 14))
            .lineLimit(nil)
            .multilineTextAlignment(textAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(width: width, alignment: frameAlignment)
            .frame(minHeight: isHeader ? 42 : 46)
            .fixedSize(horizontal: false, vertical: true)
            .background(background)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.markdownTableBorder)
                    .frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.markdownTableBorder)
                    .frame(height: 1)
            }
    }

    private var background: Color {
        if isHeader {
            return .markdownTableHeaderBackground
        }
        return isAlternateRow ? .markdownTableAlternateRowBackground : .markdownTableRowBackground
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}

private extension Color {
    static var markdownTableBorder: Color {
        Color.white.opacity(0.18)
    }

    static var markdownTableHeaderBackground: Color {
        Color.white.opacity(0.12)
    }

    static var markdownTableRowBackground: Color {
        Color.white.opacity(0.04)
    }

    static var markdownTableAlternateRowBackground: Color {
        Color.white.opacity(0.07)
    }
}

#Preview {
    if let table = MarkdownTableParser.parse("""
    | 类型 | 文档或风险 | 处理 |
    | --- | --- | --- |
    | 关联 PRD | 《地图 Map 交互 PRD》 | 承接地图手势、Drop Pin、地址栏拖拽、地图容器细节 |
    | 开放风险 | `MossCode Route` 具体结构需要三端共同评审 | 本 PRD 记录当前 CLOUD 字段，不冻结 `data.routeData` 内部结构 |
    """) {
        MarkdownTableView(table: table)
            .padding()
            .background(Color.black.opacity(0.9))
    }
}
