//
//  MarkdownRenderer.swift
//  MarkdownDemo
//

import Foundation
import SwiftUI

struct MarkdownRenderer {

    /// LaTeX 公式信息
    struct LaTeXFormula {
        let content: String
        let isBlock: Bool  // true = 块级公式 \[...\] 或 $$...$$, false = 行内公式 \(...\) 或 $...$
    }

    static func render(markdown: String) -> AttributedString {
        // 预处理：识别并替换 LaTeX 公式
        let (processedMarkdown, formulas) = preprocessLaTeX(markdown)
        if !formulas.isEmpty {
            let blockCount = formulas.values.filter(\.isBlock).count
            let inlineCount = formulas.count - blockCount
            print("🧮 LaTeX 公式识别: block=\(blockCount), inline=\(inlineCount)")
            print("🧮 LaTeX 预处理片段: \(String(processedMarkdown.prefix(180)))")
        }

        // 将 markdown 按空行分割成 blocks
        let blocks = splitIntoBlocks(processedMarkdown)
        var result = AttributedString()

        for (index, block) in blocks.enumerated() {
            let isLast = index == blocks.count - 1
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let renderedBlock = renderBlock(trimmed, formulas: formulas)
            result += renderedBlock

            if !isLast {
                result += AttributedString("\n\n")
            }
        }

        return result
    }

    /// 将 markdown 文本分割成 blocks
    private static func splitIntoBlocks(_ markdown: String) -> [String] {
        // 按一个或多个空行分割
        let pattern = "\\n\\s*\\n"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [markdown]
        }

        let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: markdown.utf16.count))

        var blocks: [String] = []
        var currentIndex = markdown.startIndex

        for match in matches {
            if let range = Range(match.range, in: markdown) {
                let block = String(markdown[currentIndex..<range.lowerBound])
                if !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(block)
                }
                currentIndex = range.upperBound
            }
        }

        // 添加最后一段
        let lastBlock = String(markdown[currentIndex...])
        if !lastBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(lastBlock)
        }

        return blocks.isEmpty ? [markdown] : blocks
    }

    /// 预处理 LaTeX 公式
    private static func preprocessLaTeX(_ markdown: String) -> (String, [String: LaTeXFormula]) {
        var formulas: [String: LaTeXFormula] = [:]
        var result = markdown
        var formulaIndex = 0

        // 块级公式: \[...\]
        let blockPattern = "\\\\\\[(.*?)\\\\\\]"
        if let regex = try? NSRegularExpression(pattern: blockPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                if let range = Range(contentRange, in: result) {
                    let content = String(result[range])
                    let placeholder = latexPlaceholder(for: formulaIndex)
                    formulas[placeholder] = LaTeXFormula(content: content, isBlock: true)
                    formulaIndex += 1
                    result = (result as NSString).replacingCharacters(in: fullRange, with: placeholder)
                }
            }
        }

        // 块级公式: $$...$$
        let dollarBlockPattern = "\\$\\$(.*?)\\$\\$"
        if let regex = try? NSRegularExpression(pattern: dollarBlockPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                if let range = Range(contentRange, in: result) {
                    let content = String(result[range])
                    let placeholder = latexPlaceholder(for: formulaIndex)
                    formulas[placeholder] = LaTeXFormula(content: content, isBlock: true)
                    formulaIndex += 1
                    result = (result as NSString).replacingCharacters(in: fullRange, with: placeholder)
                }
            }
        }

        // 行内公式: \(...\)
        let inlinePattern = "\\\\\\((.*?)\\\\\\)"
        if let regex = try? NSRegularExpression(pattern: inlinePattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                if let range = Range(contentRange, in: result) {
                    let content = String(result[range])
                    let placeholder = latexPlaceholder(for: formulaIndex)
                    formulas[placeholder] = LaTeXFormula(content: content, isBlock: false)
                    formulaIndex += 1
                    result = (result as NSString).replacingCharacters(in: fullRange, with: placeholder)
                }
            }
        }

        // 行内公式: $...$
        let dollarInlinePattern = "(?<!\\\\)\\$(?!\\$)(.*?)(?<!\\\\)\\$"
        if let regex = try? NSRegularExpression(pattern: dollarInlinePattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                if let range = Range(contentRange, in: result) {
                    let content = String(result[range])
                    let placeholder = latexPlaceholder(for: formulaIndex)
                    formulas[placeholder] = LaTeXFormula(content: content, isBlock: false)
                    formulaIndex += 1
                    result = (result as NSString).replacingCharacters(in: fullRange, with: placeholder)
                }
            }
        }

        return (result, formulas)
    }

    private static func latexPlaceholder(for index: Int) -> String {
        "LATEXFORMULATOKEN\(index)END"
    }

    /// 判断 block 类型并渲染
    private static func renderBlock(_ block: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)

        // 代码块
        if trimmed.hasPrefix("```") {
            if isMermaidBlock(trimmed) {
                return renderMermaidBlock(trimmed)
            }
            return renderCodeBlock(trimmed)
        }

        // 有序列表 - 检查每一行是否以数字开头
        if isOrderedList(trimmed) {
            return renderOrderedList(trimmed, formulas: formulas)
        }

        // 无序列表
        if isUnorderedList(trimmed) {
            return renderUnorderedList(trimmed, formulas: formulas)
        }

        // 表格
        if isTable(trimmed) {
            return renderTableBlock(trimmed, formulas: formulas)
        }

        // 引用块
        if trimmed.hasPrefix(">") {
            return renderBlockQuote(trimmed, formulas: formulas)
        }

        // 分隔线
        if isThematicBreak(trimmed) {
            return renderThematicBreak()
        }

        // 标题
        if let headingLevel = detectHeadingLevel(trimmed) {
            return renderHeading(trimmed, level: headingLevel, formulas: formulas)
        }

        // 普通段落
        return renderParagraph(trimmed, formulas: formulas)
    }

    /// 检测是否为有序列表
    private static func isOrderedList(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmptyLines.isEmpty else { return false }

        // 检查第一行是否以数字.开头
        let firstLine = nonEmptyLines[0].trimmingCharacters(in: .whitespaces)
        let pattern = "^\\d+[.)]\\s"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           regex.firstMatch(in: firstLine, options: [], range: NSRange(location: 0, length: firstLine.utf16.count)) != nil {
            return true
        }
        return false
    }

    /// 检测是否为无序列表
    private static func isUnorderedList(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmptyLines.isEmpty else { return false }

        let firstLine = nonEmptyLines[0].trimmingCharacters(in: .whitespaces)
        return firstLine.hasPrefix("- ") || firstLine.hasPrefix("* ") || firstLine.hasPrefix("+ ")
    }

    /// 检测是否为表格
    private static func isTable(_ text: String) -> Bool {
        MarkdownTableParser.parse(text) != nil
    }

    /// 检测是否为分隔线
    private static func isThematicBreak(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let pattern = "^([-*_])(\\s*\\1){2,}$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
            return true
        }
        return trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___")
    }

    /// 检测标题级别
    private static func detectHeadingLevel(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level)
            if trimmed.hasPrefix(prefix + " ") || trimmed.hasPrefix(prefix + "\t") {
                return level
            }
        }
        return nil
    }

    /// 渲染标题
    private static func renderHeading(_ text: String, level: Int, formulas: [String: LaTeXFormula]) -> AttributedString {
        var content = text.trimmingCharacters(in: .whitespaces)

        // 去除开头的 # 标记
        let prefix = String(repeating: "#", count: level)
        if content.hasPrefix(prefix) {
            content = String(content.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        }

        // 使用原生 markdown 解析内容
        let attr = parseInlineMarkdown(content, formulas: formulas)

        // 应用标题样式
        let fontSize: CGFloat
        switch level {
        case 1: fontSize = 30
        case 2: fontSize = 26
        case 3: fontSize = 22
        case 4: fontSize = 18
        case 5: fontSize = 16
        case 6: fontSize = 14
        default: fontSize = 16
        }

        // 应用字体和颜色
        var styled = AttributedString()
        for run in attr.runs {
            var runAttr = AttributedString(attr[run.range])
            runAttr.font = .misans(.semibold, size: fontSize)
            runAttr.foregroundColor = .white
            styled.append(runAttr)
        }

        if styled.characters.isEmpty {
            styled = attr
            styled.font = .misans(.semibold, size: fontSize)
            styled.foregroundColor = .white
        }

        return styled
    }

    /// 渲染段落
    private static func renderParagraph(_ text: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseInlineMarkdown(content, formulas: formulas)
    }

    /// 渲染无序列表
    private static func renderUnorderedList(_ text: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 检查是否是列表项
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var bullet = AttributedString("• ")
                bullet.foregroundColor = .white
                bullet.font = .misans(.medium, size: 16)
                result.append(bullet)

                let content = String(trimmed.dropFirst(2))
                let itemContent = parseInlineMarkdown(content, formulas: formulas)
                result.append(itemContent)
                result.append(AttributedString("\n"))
            } else {
                // 可能是列表项的续行
                let itemContent = parseInlineMarkdown(trimmed, formulas: formulas)
                result.append(itemContent)
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    /// 渲染有序列表
    private static func renderOrderedList(_ text: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: .newlines)
        var itemNumber = 1

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 检查是否是列表项 (数字. 或 数字) )
            let pattern = "^(\\d+)[.)]\\s"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)),
               let matchRange = Range(match.range, in: trimmed),
               let numberRange = Range(match.range(at: 1), in: trimmed) {
                let explicitNumber = String(trimmed[numberRange])
                if let num = Int(explicitNumber) {
                    itemNumber = num
                }

                var numberStr = AttributedString("\(itemNumber). ")
                numberStr.foregroundColor = .gray
                numberStr.font = .misans(.semibold, size: 16)
                result.append(numberStr)

                let afterNumber = String(trimmed[matchRange.upperBound...])
                let itemContent = parseInlineMarkdown(afterNumber, formulas: formulas)
                result.append(itemContent)
                result.append(AttributedString("\n"))
                itemNumber += 1
            } else {
                // 续行
                let itemContent = parseInlineMarkdown(trimmed, formulas: formulas)
                result.append(itemContent)
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    /// 渲染代码块
    private static func renderCodeBlock(_ text: String) -> AttributedString {
        var lines = text.components(separatedBy: .newlines)

        // 去除开头的 ```
        if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeFirst()
        }

        // 去除结尾的 ```
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeLast()
        }

        let codeContent = lines.joined(separator: "\n")
        var codeAttr = AttributedString(codeContent)
        codeAttr.font = .misans(.medium, size: 14)
        codeAttr.foregroundColor = .gray
        codeAttr.backgroundColor = .gray.opacity(0.1)

        return codeAttr
    }

    private static func isMermaidBlock(_ text: String) -> Bool {
        guard let firstLine = text.components(separatedBy: .newlines).first else {
            return false
        }
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "```mermaid"
    }

    private static func renderMermaidBlock(_ text: String) -> AttributedString {
        let content = fencedCodeContent(from: text)

        var result = AttributedString("Mermaid Flowchart\n")
        result.font = .misans(.semibold, size: 16)
        result.foregroundColor = .white
        result.backgroundColor = .blue.opacity(0.18)

        var hint = AttributedString("Diagram rendering is not enabled yet. Source:\n")
        hint.font = .misans(.medium, size: 14)
        hint.foregroundColor = .gray
        result.append(hint)

        var source = AttributedString(content)
        source.font = .system(.body, design: .monospaced)
        source.foregroundColor = .white
        source.backgroundColor = .blue.opacity(0.08)
        result.append(source)

        return result
    }

    private static func fencedCodeContent(from text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    /// 渲染引用块
    private static func renderBlockQuote(_ text: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        var result = AttributedString()

        var quoteSymbol = AttributedString("❝ ")
        quoteSymbol.foregroundColor = .gray
        quoteSymbol.font = .misans(.semibold, size: 16)
        result.append(quoteSymbol)

        let lines = text.components(separatedBy: .newlines)
        var content = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">") {
                let afterQuote = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    content += " "
                }
                content += afterQuote
            }
        }

        let contentAttr = parseInlineMarkdown(content, formulas: formulas)
        result.append(contentAttr)

        return result
    }

    /// 渲染分隔线
    private static func renderThematicBreak() -> AttributedString {
        var line = AttributedString(String(repeating: "─", count: 30))
        line.foregroundColor = .white
        return line
    }

    /// 渲染表格
    private static func renderTableBlock(_ text: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        guard let table = MarkdownTableParser.parse(text) else {
            return renderParagraph(text, formulas: formulas)
        }

        var result = AttributedString()

        let columnWidths = tableColumnWidths(table)
        result += tableBorder(left: "┌", separator: "┬", right: "┐", widths: columnWidths)
        result += tableRow(table.headers, widths: columnWidths, alignments: table.alignments, formulas: formulas, isHeader: true)
        result += tableBorder(left: "├", separator: "┼", right: "┤", widths: columnWidths)

        for row in table.rows {
            result += tableRow(row, widths: columnWidths, alignments: table.alignments, formulas: formulas, isHeader: false)
        }

        result += tableBorder(left: "└", separator: "┴", right: "┘", widths: columnWidths)
        return result
    }

    private static func tableColumnWidths(_ table: MarkdownTable) -> [Int] {
        var widths = table.headers.map { displayWidth($0) }

        for row in table.rows {
            for (index, cell) in row.enumerated() where index < widths.count {
                widths[index] = max(widths[index], displayWidth(cell))
            }
        }

        return widths.map { min(max($0, 4), 48) }
    }

    private static func tableBorder(left: String, separator: String, right: String, widths: [Int]) -> AttributedString {
        let line = left + widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: separator) + right + "\n"
        var attr = AttributedString(line)
        attr.font = .system(.body, design: .monospaced)
        attr.foregroundColor = .gray
        return attr
    }

    private static func tableRow(
        _ cells: [String],
        widths: [Int],
        alignments: [MarkdownTable.Alignment],
        formulas: [String: LaTeXFormula],
        isHeader: Bool
    ) -> AttributedString {
        var result = AttributedString("│ ")
        result.font = .system(.body, design: .monospaced)
        result.foregroundColor = .gray

        for index in widths.indices {
            let cell = index < cells.count ? cells[index] : ""
            let alignment = index < alignments.count ? alignments[index] : .left
            let paddedCell = padded(cell, width: widths[index], alignment: alignment)
            var content = parseInlineMarkdown(paddedCell, formulas: formulas)
            content.font = isHeader ? .misans(.semibold, size: 15) : .misans(.medium, size: 15)
            result += content

            var separator = AttributedString(index == widths.indices.last ? " │\n" : " │ ")
            separator.font = .system(.body, design: .monospaced)
            separator.foregroundColor = .gray
            result += separator
        }

        return result
    }

    private static func padded(_ text: String, width: Int, alignment: MarkdownTable.Alignment) -> String {
        let textWidth = displayWidth(text)
        guard textWidth < width else { return text }

        let padding = width - textWidth
        switch alignment {
        case .left:
            return text + String(repeating: " ", count: padding)
        case .right:
            return String(repeating: " ", count: padding) + text
        case .center:
            let left = padding / 2
            let right = padding - left
            return String(repeating: " ", count: left) + text + String(repeating: " ", count: right)
        }
    }

    private static func displayWidth(_ text: String) -> Int {
        text.reduce(0) { width, character in
            width + (character.isASCII ? 1 : 2)
        }
    }

    /// 行内 markdown 解析（使用原生 AttributedString）
    private static func parseInlineMarkdown(_ text: String, formulas: [String: LaTeXFormula]) -> AttributedString {
        // 使用原生 markdown 解析行内元素
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace

            let attr = try AttributedString(markdown: text, options: options)

            // 应用 MiSans 字体和颜色，并处理特殊格式
            return applyStyling(attr, formulas: formulas)
        } catch {
            // 如果解析失败，返回纯文本
            var plain = AttributedString(text)
            plain.font = .misans(.medium, size: 16)
            plain.foregroundColor = .white
            return processLaTeXPlaceholders(plain, formulas: formulas)
        }
    }

    /// 应用样式到 AttributedString
    private static func applyStyling(_ attr: AttributedString, formulas: [String: LaTeXFormula]) -> AttributedString {
        var result = AttributedString()

        for run in attr.runs {
            var runAttr = AttributedString(attr[run.range])

            // 检查是否是链接
            if let link = run.link {
                runAttr.foregroundColor = .blue
                runAttr.underlineStyle = .single
                runAttr.link = link
                runAttr.font = .misans(.medium, size: 16)
            }
            // 检查是否是代码（通过字体特征判断）
            else if let currentFont = run.font, isMonospaceFont(currentFont) {
                runAttr.font = .system(.body, design: .monospaced)
                runAttr.backgroundColor = .gray.opacity(0.15)
                runAttr.foregroundColor = .white
            }
            // 检查是否是强调/粗体
            else if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                runAttr.font = .misans(.semibold, size: 16)
                runAttr.foregroundColor = .white
            }
            else if run.inlinePresentationIntent?.contains(.emphasized) == true {
                runAttr.font = .system(size: 16).italic()
                runAttr.foregroundColor = .white
            }
            else if run.inlinePresentationIntent?.contains(.code) == true {
                runAttr.font = .system(.body, design: .monospaced)
                runAttr.backgroundColor = .gray.opacity(0.15)
                runAttr.foregroundColor = .white
            }
            else {
                runAttr.font = .misans(.medium, size: 16)
                runAttr.foregroundColor = .white
            }

            // 处理 LaTeX 占位符
            runAttr = processLaTeXPlaceholders(runAttr, formulas: formulas)

            result.append(runAttr)
        }

        if result.characters.isEmpty {
            result = attr
            result.font = .misans(.medium, size: 16)
            result.foregroundColor = .white
            result = processLaTeXPlaceholders(result, formulas: formulas)
        }

        return result
    }

    /// 判断是否为等宽字体
    private static func isMonospaceFont(_ font: Font) -> Bool {
        // 简单判断：检查字体是否包含 mono 或等宽特征
        // 由于 Font 无法直接检查，我们通过样式来判断
        return false
    }

    /// 处理 LaTeX 占位符，渲染为公式样式
    private static func processLaTeXPlaceholders(_ attr: AttributedString, formulas: [String: LaTeXFormula]) -> AttributedString {
        let text = String(attr.characters)
        let pattern = "LATEXFORMULATOKEN(\\d+)END"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attr
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        if matches.isEmpty {
            return attr
        }

        var result = AttributedString()
        var currentIndex = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let indexRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let index = String(text[indexRange])
            let placeholder = latexPlaceholder(for: Int(index) ?? -1)

            // 添加占位符前的文本
            if currentIndex < matchRange.lowerBound {
                let beforeText = String(text[currentIndex..<matchRange.lowerBound])
                var beforeAttr = AttributedString(beforeText)
                beforeAttr.font = .misans(.medium, size: 16)
                beforeAttr.foregroundColor = .white

                // 从原始 attr 中复制样式
                if let originalRange = attr.range(of: beforeText) {
                    let originalSlice = attr[originalRange]
                    if let link = originalSlice.link {
                        beforeAttr.link = link
                        beforeAttr.foregroundColor = .blue
                        beforeAttr.underlineStyle = .single
                    }
                }

                result += beforeAttr
            }

            // 渲染 LaTeX 公式
            if let formula = formulas[placeholder] {
                let renderedFormula = renderLaTeXText(formula.content)
                print("🧮 渲染 LaTeX \(formula.isBlock ? "block" : "inline"): \(renderedFormula)")
                var formulaAttr = AttributedString(renderedFormula)
                formulaAttr.font = .system(.body, design: .monospaced)
                formulaAttr.foregroundColor = formula.isBlock ? .yellow.opacity(0.9) : .cyan.opacity(0.9)

                if formula.isBlock {
                    result += AttributedString("\n")
                    formulaAttr.backgroundColor = .gray.opacity(0.1)
                    result += formulaAttr
                    result += AttributedString("\n")
                } else {
                    result += formulaAttr
                }
            }

            currentIndex = matchRange.upperBound
        }

        // 添加剩余文本
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            var remainingAttr = AttributedString(remainingText)
            remainingAttr.font = .misans(.medium, size: 16)
            remainingAttr.foregroundColor = .white
            result += remainingAttr
        }

        return result
    }

    /// 将常见 LaTeX 公式语法转换成适合 Text/AttributedString 展示的数学文本。
    private static func renderLaTeXText(_ formula: String) -> String {
        var text = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\n", with: " ")

        text = replaceLatexCommandArgument(in: text, commands: ["text", "mathrm", "operatorname"]) { value in
            value
        }
        text = replaceLatexCommandArgument(in: text, commands: ["sqrt"]) { value in
            "√(\(value))"
        }
        text = replaceLatexFractions(in: text)

        let replacements: [String: String] = [
            "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
            "\\epsilon": "ε", "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ",
            "\\iota": "ι", "\\kappa": "κ", "\\lambda": "λ", "\\mu": "μ",
            "\\nu": "ν", "\\xi": "ξ", "\\pi": "π", "\\rho": "ρ",
            "\\sigma": "σ", "\\tau": "τ", "\\upsilon": "υ", "\\phi": "φ",
            "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
            "\\Gamma": "Γ", "\\Delta": "Δ", "\\Theta": "Θ", "\\Lambda": "Λ",
            "\\Xi": "Ξ", "\\Pi": "Π", "\\Sigma": "Σ", "\\Phi": "Φ",
            "\\Psi": "Ψ", "\\Omega": "Ω",
            "\\sum": "Σ", "\\prod": "Π", "\\int": "∫", "\\lim": "lim",
            "\\infty": "∞", "\\pm": "±", "\\times": "×", "\\cdot": "·",
            "\\div": "÷", "\\leq": "≤", "\\le": "≤", "\\geq": "≥", "\\ge": "≥",
            "\\neq": "≠", "\\ne": "≠", "\\approx": "≈", "\\equiv": "≡",
            "\\to": "→", "\\rightarrow": "→", "\\leftarrow": "←",
            "\\in": "∈", "\\notin": "∉", "\\subset": "⊂", "\\subseteq": "⊆",
            "\\supset": "⊃", "\\supseteq": "⊇", "\\cup": "∪", "\\cap": "∩",
            "\\emptyset": "∅", "\\forall": "∀", "\\exists": "∃",
            "\\land": "∧", "\\lor": "∨", "\\neg": "¬",
            "\\left": "", "\\right": "", "\\,": " ", "\\;": " ", "\\:": " ", "\\!": ""
        ]

        for (latex, symbol) in replacements {
            text = text.replacingOccurrences(of: latex, with: symbol)
        }

        text = convertLatexScripts(in: text)
        text = text.replacingOccurrences(of: "\\\\", with: "\n")
        text = text.replacingOccurrences(of: "\\{", with: "{")
        text = text.replacingOccurrences(of: "\\}", with: "}")
        text = text.replacingOccurrences(of: "\\", with: "")
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceLatexFractions(in text: String) -> String {
        replaceMatches(in: text, pattern: "\\\\frac\\{([^{}]+)\\}\\{([^{}]+)\\}") { match, source in
            guard let numeratorRange = Range(match.range(at: 1), in: source),
                  let denominatorRange = Range(match.range(at: 2), in: source) else {
                return ""
            }
            return "\(source[numeratorRange])⁄\(source[denominatorRange])"
        }
    }

    private static func replaceLatexCommandArgument(
        in text: String,
        commands: [String],
        transform: (String) -> String
    ) -> String {
        let commandPattern = commands.joined(separator: "|")
        return replaceMatches(in: text, pattern: "\\\\(?:\(commandPattern))\\{([^{}]*)\\}") { match, source in
            guard let valueRange = Range(match.range(at: 1), in: source) else {
                return ""
            }
            return transform(String(source[valueRange]))
        }
    }

    private static func convertLatexScripts(in text: String) -> String {
        let afterSuperscripts = replaceMatches(in: text, pattern: "\\^\\{([^{}]+)\\}|\\^([A-Za-z0-9+\\-=()])") { match, source in
            let value = captureValue(from: match, in: source)
            return mapScript(value, using: superscriptMap, fallbackPrefix: "^")
        }

        return replaceMatches(in: afterSuperscripts, pattern: "_\\{([^{}]+)\\}|_([A-Za-z0-9+\\-=()])") { match, source in
            let value = captureValue(from: match, in: source)
            return mapScript(value, using: subscriptMap, fallbackPrefix: "_")
        }
    }

    private static func captureValue(from match: NSTextCheckingResult, in source: String) -> String {
        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)
            if range.location != NSNotFound, let stringRange = Range(range, in: source) {
                return String(source[stringRange])
            }
        }
        return ""
    }

    private static func mapScript(_ value: String, using map: [Character: Character], fallbackPrefix: String) -> String {
        var mapped = ""
        for character in value {
            guard let replacement = map[character] else {
                return "\(fallbackPrefix){\(value)}"
            }
            mapped.append(replacement)
        }
        return mapped
    }

    private static func replaceMatches(
        in text: String,
        pattern: String,
        transform: (NSTextCheckingResult, String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var result = text
        let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
        for match in matches.reversed() {
            let replacement = transform(match, result)
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    private static let superscriptMap: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "n": "ⁿ", "i": "ⁱ"
    ]

    private static let subscriptMap: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
        "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
        "v": "ᵥ", "x": "ₓ"
    ]
}
