//
//  MarkdownTheme.swift
//  MarkdownDemo
//

import SwiftUI

struct MarkdownTheme {
    let background: Color
    let text: Color

    let heading1: Color
    let heading2: Color
    let heading3: Color
    let heading4: Color

    let link: Color
    let bold: Color
    let codeText: Color
    let codeBackground: Color
    let inlineCodeText: Color
    let inlineCodeBackground: Color

    let blockquoteBorder: Color
    let blockquoteText: Color
    let thematicBreak: Color
    let quoteMark: Color

    let tableBorder: Color
    let tableHeaderBackground: Color
    let tableRowBackground: Color
    let tableAlternateRow: Color

    let latexBlock: Color
    let latexInline: Color
    let latexBackground: Color

    let mermaidBackground: Color
    let mermaidHint: Color

    let editorBackground: Color
    let editorHeaderBackground: Color

    // MARK: - Light Theme

    static let light = MarkdownTheme(
        background:          Color(white: 0.98),
        text:                Color(red: 0.11, green: 0.11, blue: 0.11),
        heading1:            Color(red: 0.15, green: 0.39, blue: 0.92),
        heading2:            Color(red: 0.49, green: 0.23, blue: 0.93),
        heading3:            Color(red: 0.02, green: 0.59, blue: 0.41),
        heading4:            Color(red: 0.85, green: 0.47, blue: 0.04),
        link:                Color(red: 0.15, green: 0.39, blue: 0.92),
        bold:                Color(red: 0.07, green: 0.07, blue: 0.07),
        codeText:            Color(red: 0.23, green: 0.25, blue: 0.32),
        codeBackground:      Color(red: 0.95, green: 0.96, blue: 0.97),
        inlineCodeText:      Color(red: 0.11, green: 0.31, blue: 0.84),
        inlineCodeBackground:Color(red: 0.94, green: 0.96, blue: 1.0),
        blockquoteBorder:    Color(red: 0.15, green: 0.39, blue: 0.92),
        blockquoteText:      Color(red: 0.42, green: 0.45, blue: 0.50),
        thematicBreak:       Color(red: 0.82, green: 0.84, blue: 0.86),
        quoteMark:           Color(red: 0.60, green: 0.63, blue: 0.68),
        tableBorder:         Color(red: 0.90, green: 0.91, blue: 0.92),
        tableHeaderBackground:Color(red: 0.98, green: 0.98, blue: 0.99),
        tableRowBackground:  Color.white,
        tableAlternateRow:   Color(white: 0.98),
        latexBlock:          Color(red: 0.85, green: 0.47, blue: 0.04),
        latexInline:         Color(red: 0.02, green: 0.59, blue: 0.41),
        latexBackground:     Color(red: 0.95, green: 0.96, blue: 0.97),
        mermaidBackground:   Color(red: 0.95, green: 0.96, blue: 0.97),
        mermaidHint:         Color(red: 0.42, green: 0.45, blue: 0.50),
        editorBackground:    Color(white: 0.98),
        editorHeaderBackground: Color(white: 0.96)
    )

    // MARK: - Dark Theme

    static let dark = MarkdownTheme(
        background:          Color(white: 0.08),
        text:                Color(white: 0.92),
        heading1:            Color(red: 0.45, green: 0.62, blue: 1.0),
        heading2:            Color(red: 0.72, green: 0.52, blue: 1.0),
        heading3:            Color(red: 0.30, green: 0.85, blue: 0.62),
        heading4:            Color(red: 1.0, green: 0.70, blue: 0.25),
        link:                Color(red: 0.45, green: 0.62, blue: 1.0),
        bold:                Color(white: 0.98),
        codeText:            Color(red: 0.82, green: 0.86, blue: 0.94),
        codeBackground:      Color(white: 0.16),
        inlineCodeText:      Color(red: 0.60, green: 0.75, blue: 1.0),
        inlineCodeBackground:Color(red: 0.18, green: 0.22, blue: 0.35),
        blockquoteBorder:    Color(red: 0.45, green: 0.62, blue: 1.0),
        blockquoteText:      Color(red: 0.65, green: 0.68, blue: 0.72),
        thematicBreak:       Color(white: 0.22),
        quoteMark:           Color(red: 0.50, green: 0.54, blue: 0.60),
        tableBorder:         Color(white: 0.20),
        tableHeaderBackground:Color(white: 0.14),
        tableRowBackground:  Color(white: 0.10),
        tableAlternateRow:   Color(white: 0.13),
        latexBlock:          Color(red: 1.0, green: 0.70, blue: 0.25),
        latexInline:         Color(red: 0.30, green: 0.85, blue: 0.62),
        latexBackground:     Color(white: 0.16),
        mermaidBackground:   Color(white: 0.14),
        mermaidHint:         Color(red: 0.65, green: 0.68, blue: 0.72),
        editorBackground:    Color(white: 0.10),
        editorHeaderBackground: Color(white: 0.14)
    )
}

// MARK: - Environment

private struct MarkdownThemeKey: EnvironmentKey {
    static let defaultValue: MarkdownTheme = .light
}

extension EnvironmentValues {
    var markdownTheme: MarkdownTheme {
        get { self[MarkdownThemeKey.self] }
        set { self[MarkdownThemeKey.self] = newValue }
    }
}

extension View {
    func markdownTheme(_ theme: MarkdownTheme) -> some View {
        environment(\.markdownTheme, theme)
    }
}
