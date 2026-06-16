//
//  MarkdownAppDestination.swift
//  MarkdownDemo
//

enum MarkdownAppDestination {
    case caseList
    case editor

    nonisolated static var `default`: MarkdownAppDestination {
        #if os(macOS)
        .editor
        #else
        .caseList
        #endif
    }
}
