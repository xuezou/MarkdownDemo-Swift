//
//  ContentView.swift
//  MarkdownDemo
//
//  Created by 曹凯 on 2026/5/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        switch MarkdownAppDestination.default {
        case .caseList:
            MarkdownCaseListView()
        case .editor:
            #if os(macOS)
            MarkdownEditorView()
            #else
            MarkdownCaseListView()
            #endif
        }
    }
}

#Preview {
    ContentView()
}
