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

    static func render(markdown: String, theme: MarkdownTheme = .light) -> AttributedString {
        let (processedMarkdown, formulas) = preprocessLaTeX(markdown)

        let blocks = splitIntoBlocks(processedMarkdown)
        var result = AttributedString()

        for (index, block) in blocks.enumerated() {
            let isLast = index == blocks.count - 1
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let renderedBlock = renderBlock(trimmed, formulas: formulas, theme: theme)
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

    private static func renderBlock(_ block: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            if isMermaidBlock(trimmed) {
                return renderMermaidBlock(trimmed, theme: theme)
            }
            return renderCodeBlock(trimmed, theme: theme)
        }

        if isOrderedList(trimmed) {
            return renderOrderedList(trimmed, formulas: formulas, theme: theme)
        }

        if isUnorderedList(trimmed) {
            return renderUnorderedList(trimmed, formulas: formulas, theme: theme)
        }

        if isTable(trimmed) {
            return renderTableBlock(trimmed, formulas: formulas, theme: theme)
        }

        if trimmed.hasPrefix(">") {
            return renderBlockQuote(trimmed, formulas: formulas, theme: theme)
        }

        if isThematicBreak(trimmed) {
            return renderThematicBreak(theme: theme)
        }

        if let headingLevel = detectHeadingLevel(trimmed) {
            return renderHeading(trimmed, level: headingLevel, formulas: formulas, theme: theme)
        }

        return renderParagraph(trimmed, formulas: formulas, theme: theme)
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
    private static func renderHeading(_ text: String, level: Int, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        var content = text.trimmingCharacters(in: .whitespaces)

        let prefix = String(repeating: "#", count: level)
        if content.hasPrefix(prefix) {
            content = String(content.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        }

        let attr = parseInlineMarkdown(content, formulas: formulas, theme: theme)

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

        let color: Color
        switch level {
        case 1: color = theme.heading1
        case 2: color = theme.heading2
        case 3: color = theme.heading3
        default: color = theme.heading4
        }

        var styled = AttributedString()
        for run in attr.runs {
            var runAttr = AttributedString(attr[run.range])
            runAttr.font = .misans(.semibold, size: fontSize)
            runAttr.foregroundColor = color
            styled.append(runAttr)
        }

        if styled.characters.isEmpty {
            styled = attr
            styled.font = .misans(.semibold, size: fontSize)
            styled.foregroundColor = color
        }

        return styled
    }

    /// 渲染段落
    private static func renderParagraph(_ text: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseInlineMarkdown(content, formulas: formulas, theme: theme)
    }

    /// 渲染无序列表
    private static func renderUnorderedList(_ text: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var bullet = AttributedString("• ")
                bullet.foregroundColor = theme.heading2
                bullet.font = .misans(.medium, size: 16)
                result.append(bullet)

                let content = String(trimmed.dropFirst(2))
                let itemContent = parseInlineMarkdown(content, formulas: formulas, theme: theme)
                result.append(itemContent)
                result.append(AttributedString("\n"))
            } else {
                let itemContent = parseInlineMarkdown(trimmed, formulas: formulas, theme: theme)
                result.append(itemContent)
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    /// 渲染有序列表
    private static func renderOrderedList(_ text: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: .newlines)
        var itemNumber = 1

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

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
                numberStr.foregroundColor = theme.quoteMark
                numberStr.font = .misans(.semibold, size: 16)
                result.append(numberStr)

                let afterNumber = String(trimmed[matchRange.upperBound...])
                let itemContent = parseInlineMarkdown(afterNumber, formulas: formulas, theme: theme)
                result.append(itemContent)
                result.append(AttributedString("\n"))
                itemNumber += 1
            } else {
                let itemContent = parseInlineMarkdown(trimmed, formulas: formulas, theme: theme)
                result.append(itemContent)
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    /// 渲染代码块
    private static func renderCodeBlock(_ text: String, theme: MarkdownTheme) -> AttributedString {
        var lines = text.components(separatedBy: .newlines)

        if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeFirst()
        }

        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeLast()
        }

        let codeContent = lines.joined(separator: "\n")
        var codeAttr = AttributedString(codeContent)
        codeAttr.font = .system(.body, design: .monospaced)
        codeAttr.foregroundColor = theme.codeText
        codeAttr.backgroundColor = theme.codeBackground

        return codeAttr
    }

    private static func isMermaidBlock(_ text: String) -> Bool {
        guard let firstLine = text.components(separatedBy: .newlines).first else {
            return false
        }
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "```mermaid"
    }

    private static func renderMermaidBlock(_ text: String, theme: MarkdownTheme) -> AttributedString {
        let content = fencedCodeContent(from: text)

        var result = AttributedString("Mermaid Flowchart\n")
        result.font = .misans(.semibold, size: 16)
        result.foregroundColor = theme.text
        result.backgroundColor = theme.mermaidBackground

        var hint = AttributedString("Diagram rendering is not enabled yet. Source:\n")
        hint.font = .misans(.medium, size: 14)
        hint.foregroundColor = theme.mermaidHint
        result.append(hint)

        var source = AttributedString(content)
        source.font = .system(.body, design: .monospaced)
        source.foregroundColor = theme.codeText
        source.backgroundColor = theme.mermaidBackground
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
    private static func renderBlockQuote(_ text: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        var result = AttributedString()

        var quoteSymbol = AttributedString("❝ ")
        quoteSymbol.foregroundColor = theme.quoteMark
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

        let contentAttr = parseInlineMarkdown(content, formulas: formulas, theme: theme)
        result.append(contentAttr)

        return result
    }

    /// 渲染分隔线
    private static func renderThematicBreak(theme: MarkdownTheme) -> AttributedString {
        var line = AttributedString(String(repeating: "─", count: 30))
        line.foregroundColor = theme.thematicBreak
        return line
    }

    /// 渲染表格
    private static func renderTableBlock(_ text: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        guard let table = MarkdownTableParser.parse(text) else {
            return renderParagraph(text, formulas: formulas, theme: theme)
        }

        var result = AttributedString()

        let columnWidths = tableColumnWidths(table)
        result += tableBorder(left: "┌", separator: "┬", right: "┐", widths: columnWidths, theme: theme)
        result += tableRow(table.headers, widths: columnWidths, alignments: table.alignments, formulas: formulas, isHeader: true, theme: theme)
        result += tableBorder(left: "├", separator: "┼", right: "┤", widths: columnWidths, theme: theme)

        for row in table.rows {
            result += tableRow(row, widths: columnWidths, alignments: table.alignments, formulas: formulas, isHeader: false, theme: theme)
        }

        result += tableBorder(left: "└", separator: "┴", right: "┘", widths: columnWidths, theme: theme)
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

    private static func tableBorder(left: String, separator: String, right: String, widths: [Int], theme: MarkdownTheme) -> AttributedString {
        let line = left + widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: separator) + right + "\n"
        var attr = AttributedString(line)
        attr.font = .system(.body, design: .monospaced)
        attr.foregroundColor = theme.tableBorder
        return attr
    }

    private static func tableRow(
        _ cells: [String],
        widths: [Int],
        alignments: [MarkdownTable.Alignment],
        formulas: [String: LaTeXFormula],
        isHeader: Bool,
        theme: MarkdownTheme
    ) -> AttributedString {
        var result = AttributedString("│ ")
        result.font = .system(.body, design: .monospaced)
        result.foregroundColor = theme.tableBorder

        for index in widths.indices {
            let cell = index < cells.count ? cells[index] : ""
            let alignment = index < alignments.count ? alignments[index] : .left
            let paddedCell = padded(cell, width: widths[index], alignment: alignment)
            var content = parseInlineMarkdown(paddedCell, formulas: formulas, theme: theme)
            content.font = isHeader ? .misans(.semibold, size: 15) : .misans(.medium, size: 15)
            result += content

            var separator = AttributedString(index == widths.indices.last ? " │\n" : " │ ")
            separator.font = .system(.body, design: .monospaced)
            separator.foregroundColor = theme.tableBorder
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

    /// 行内 markdown 解析
    private static func parseInlineMarkdown(_ text: String, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace

            let attr = try AttributedString(markdown: text, options: options)

            return applyStyling(attr, formulas: formulas, theme: theme)
        } catch {
            var plain = AttributedString(text)
            plain.font = .misans(.medium, size: 16)
            plain.foregroundColor = theme.text
            return processLaTeXPlaceholders(plain, formulas: formulas, theme: theme)
        }
    }

    /// 应用样式到 AttributedString
    private static func applyStyling(_ attr: AttributedString, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
        var result = AttributedString()

        for run in attr.runs {
            var runAttr = AttributedString(attr[run.range])

            if let link = run.link {
                runAttr.foregroundColor = theme.link
                runAttr.underlineStyle = .single
                runAttr.link = link
                runAttr.font = .misans(.medium, size: 16)
            }
            else if let currentFont = run.font, isMonospaceFont(currentFont) {
                runAttr.font = .system(.body, design: .monospaced)
                runAttr.backgroundColor = theme.inlineCodeBackground
                runAttr.foregroundColor = theme.inlineCodeText
            }
            else if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                runAttr.font = .misans(.semibold, size: 16)
                runAttr.foregroundColor = theme.bold
            }
            else if run.inlinePresentationIntent?.contains(.emphasized) == true {
                runAttr.font = .system(size: 16).italic()
                runAttr.foregroundColor = theme.text
            }
            else if run.inlinePresentationIntent?.contains(.code) == true {
                runAttr.font = .system(.body, design: .monospaced)
                runAttr.backgroundColor = theme.inlineCodeBackground
                runAttr.foregroundColor = theme.inlineCodeText
            }
            else {
                runAttr.font = .misans(.medium, size: 16)
                runAttr.foregroundColor = theme.text
            }

            runAttr = processLaTeXPlaceholders(runAttr, formulas: formulas, theme: theme)

            result.append(runAttr)
        }

        if result.characters.isEmpty {
            result = attr
            result.font = .misans(.medium, size: 16)
            result.foregroundColor = theme.text
            result = processLaTeXPlaceholders(result, formulas: formulas, theme: theme)
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
    private static func processLaTeXPlaceholders(_ attr: AttributedString, formulas: [String: LaTeXFormula], theme: MarkdownTheme) -> AttributedString {
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

            if currentIndex < matchRange.lowerBound {
                let beforeText = String(text[currentIndex..<matchRange.lowerBound])
                var beforeAttr = AttributedString(beforeText)
                beforeAttr.font = .misans(.medium, size: 16)
                beforeAttr.foregroundColor = theme.text

                if let originalRange = attr.range(of: beforeText) {
                    let originalSlice = attr[originalRange]
                    if let link = originalSlice.link {
                        beforeAttr.link = link
                        beforeAttr.foregroundColor = theme.link
                        beforeAttr.underlineStyle = .single
                    }
                }

                result += beforeAttr
            }

            if let formula = formulas[placeholder] {
                let renderedFormula = renderLaTeXText(formula.content)
                var formulaAttr = AttributedString(renderedFormula)
                formulaAttr.font = .system(.body, design: .monospaced)
                formulaAttr.foregroundColor = formula.isBlock ? theme.latexBlock : theme.latexInline

                if formula.isBlock {
                    result += AttributedString("\n")
                    formulaAttr.backgroundColor = theme.latexBackground
                    result += formulaAttr
                    result += AttributedString("\n")
                } else {
                    result += formulaAttr
                }
            }

            currentIndex = matchRange.upperBound
        }

        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            var remainingAttr = AttributedString(remainingText)
            remainingAttr.font = .misans(.medium, size: 16)
            remainingAttr.foregroundColor = theme.text
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
