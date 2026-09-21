//
//  MarkdownDemoApp.swift
//  MarkdownDemo
//
//  Created by 曹凯 on 2026/5/21.
//

import SwiftUI

@main
struct MarkdownDemoApp: App {
    var body: some Scene {
        #if os(macOS)
        DocumentGroup(newDocument: MarkdownEditorDocument()) { file in
            MarkdownThemeRoot {
                MarkdownEditorView(document: file.$document)
            }
        }
        #else
        WindowGroup {
            MarkdownThemeRoot {
                ContentView()
            }
        }
        #endif
    }
}

/// 根据系统外观（浅色/深色）注入对应 Markdown 主题
private struct MarkdownThemeRoot<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .markdownTheme(colorScheme == .dark ? .dark : .light)
    }
}
