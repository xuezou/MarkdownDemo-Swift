//
//  MarkdownDemoTests.swift
//  MarkdownDemoTests
//
//  Created by 曹凯 on 2026/5/21.
//

import CoreGraphics
import Foundation
import Testing
@testable import MarkdownDemo

struct MarkdownDemoTests {
    private let sampleMarkdownTable = """
    | 类型 | 文档或风险 | 处理 |
    | --- | --- | --- |
    | 关联 PRD | 《地图 Map 交互 PRD》 | 承接地图手势、Drop Pin、地址栏拖拽、地图容器细节 |
    | 开放风险 | `MossCode Route` 具体结构需要三端共同评审 | 本 PRD 记录当前 CLOUD 字段，不冻结 `data.routeData` 内部结构 |
    """

    private let sampleLongMarkdownTable = """
    | 类型 | 文档或风险 | 处理 |
    | --- | --- | --- |
    | 关联 PRD | 《地图 Map 交互 PRD》 | 承接地图手势、Drop Pin、地址栏拖拽、地图容器细节 |
    | 关联 PRD | 《Action 路线使用 PRD》 | 承接 Action 中使用路线、PHI 同步入口、去起点判断、3-2-1 |
    | 关联 PRD | 《路线导入导出 PRD》 | 承接 GPX 导入导出、Strava/Komoot 同步、三方 App 打开 MossCode |
    | 关联 PRD | 《分享能力 PRD》 | 承接 APP 分享入口、好友分享、外链或系统分享 |
    | 关联 PRD | 《隐私设置 PRD》 | 承接首尾隐藏、好友可见性、个人主页展示裁剪、高斯模糊 |
    | 关联 PRD | 《轨迹 Trace PRD》 | 承接 Trace 采集、上传、解析触发和候选路线输出 |
    | 关联 PRD | 《赛段 Segment PRD》 | 承接 Segment CRUD、排行、图层叠加 |
    | 关联 PRD | 《POI 通用地点资产 PRD》 | 承接 POI 字段、分类、标签、保存 |
    | 关联 PRD | 《POI 运动消费与 PHI 同步 PRD》 | 承接 POI 作为路线输入的消费流程 |
    | 开放风险 | `MossCode Route` 具体结构需要三端共同评审 | 本 PRD 记录当前 CLOUD 字段，不冻结 `data.routeData` 内部结构 |
    | 开放风险 | PHI 离线导航字段裁剪依赖 BLE 协议和 PHI 导航实现 | 由技术方案承接 |
    | 开放风险 | Segment 向后兼容只定义能力要求 | 不进入本期 ROI 资产功能 |
    """

    private let sampleMermaidFlowchart = """
    flowchart TD
        A([路线标签管理]) --> B{标签类型}
        B -->|系统标签| C[Saved / Liked 不可删改]
        B -->|自定义标签| D{用户操作}
        D -->|创建| E[创建标签]
        D -->|重命名| F[更新标签名]
        D -->|删除| G[删除标签]
        G --> H[关联路线回到 Saved]
        C --> I([完成])
        E --> I
        F --> I
        H --> I
    """

    @Test func defaultLaunchDestinationMatchesPlatform() async throws {
        #if os(macOS)
        guard case .editor = MarkdownAppDestination.default else {
            Issue.record("macOS should launch the Markdown editor")
            return
        }
        #else
        guard case .caseList = MarkdownAppDestination.default else {
            Issue.record("iOS should launch the demo case list")
            return
        }
        #endif
    }

    @MainActor
    @Test func defaultDocumentStartsCleanWithWelcomeMarkdown() async throws {
        let document = MarkdownEditorDocument()

        #expect(document.displayName == "Untitled.md")
        #expect(document.isDirty == false)
        #expect(document.markdown.contains("# Markdown Lab"))
    }

    @MainActor
    @Test func editingMarkdownMarksDocumentDirty() async throws {
        let document = MarkdownEditorDocument(markdown: "# Start")

        document.markdown = "# Changed"

        #expect(document.isDirty == true)
        #expect(document.markdown == "# Changed")
    }

    @MainActor
    @Test func loadingMarkdownFromFileResetsDirtyStateAndUsesFileName() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try "# Loaded".write(to: url, atomically: true, encoding: .utf8)

        let document = MarkdownEditorDocument(markdown: "# Draft")
        try document.load(from: url)

        #expect(document.markdown == "# Loaded")
        #expect(document.fileURL == url)
        #expect(document.displayName == url.lastPathComponent)
        #expect(document.isDirty == false)
    }

    @MainActor
    @Test func savingMarkdownWritesFileAndClearsDirtyState() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        let document = MarkdownEditorDocument(markdown: "# Save Me")
        document.markdown = "# Saved"

        try document.save(to: url)

        let saved = try String(contentsOf: url, encoding: .utf8)
        #expect(saved == "# Saved")
        #expect(document.fileURL == url)
        #expect(document.displayName == url.lastPathComponent)
        #expect(document.isDirty == false)
    }

    @MainActor
    @Test func tableParserReadsHeaderAlignmentAndRows() async throws {
        let table = try #require(MarkdownTableParser.parse(sampleMarkdownTable))

        #expect(table.headers == ["类型", "文档或风险", "处理"])
        #expect(table.alignments == [.left, .left, .left])
        #expect(table.rows.count == 2)
        #expect(table.rows[1][1] == "`MossCode Route` 具体结构需要三端共同评审")
    }

    @MainActor
    @Test func rendererDrawsMarkdownTableWithBordersAndFullContent() async throws {
        let rendered = String(MarkdownRenderer.render(markdown: sampleMarkdownTable).characters)

        #expect(rendered.contains("┌"))
        #expect(rendered.contains("┼"))
        #expect(rendered.contains("《地图 Map 交互 PRD》"))
        #expect(rendered.contains("不冻结 data.routeData 内部结构"))
    }

    @MainActor
    @Test func rendererRecognizesMermaidFlowchartFence() async throws {
        let mermaid = """
        ```mermaid
        flowchart TD
            A([路线标签管理]) --> B{标签类型}
        ```
        """

        let rendered = String(MarkdownRenderer.render(markdown: mermaid).characters)

        #expect(rendered.contains("Mermaid Flowchart"))
        #expect(rendered.contains("路线标签管理"))
        #expect(!rendered.contains("```mermaid"))
    }

    @MainActor
    @Test func mermaidParserReadsFlowchartNodesEdgesAndLabels() async throws {
        let flowchart = try #require(MermaidFlowchartParser.parse(sampleMermaidFlowchart))

        #expect(flowchart.direction == .topDown)
        #expect(flowchart.nodes.count == 9)
        #expect(flowchart.edges.count == 11)
        #expect(flowchart.node(id: "A")?.label == "路线标签管理")
        #expect(flowchart.node(id: "A")?.shape == .stadium)
        #expect(flowchart.node(id: "B")?.shape == .decision)
        #expect(flowchart.node(id: "C")?.shape == .process)
        #expect(flowchart.edges.contains { $0.from == "B" && $0.to == "C" && $0.label == "系统标签" })
    }

    @MainActor
    @Test func mermaidLayoutPlacesTargetsBelowSourcesForTopDownCharts() async throws {
        let flowchart = try #require(MermaidFlowchartParser.parse(sampleMermaidFlowchart))
        let layout = MermaidFlowchartLayoutEngine.layout(flowchart)

        let aFrame = try #require(layout.nodeFrames["A"])
        let bFrame = try #require(layout.nodeFrames["B"])
        let cFrame = try #require(layout.nodeFrames["C"])

        #expect(aFrame.minY < bFrame.minY)
        #expect(bFrame.minY < cFrame.minY)
        #expect(layout.size.width > 0)
        #expect(layout.size.height > 0)
    }

    @MainActor
    @Test func mermaidLayoutHonorsBottomTopDirection() async throws {
        let flowchart = try #require(MermaidFlowchartParser.parse("""
        flowchart BT
            A[Start] --> B[Finish]
        """))
        let layout = MermaidFlowchartLayoutEngine.layout(flowchart)

        let startFrame = try #require(layout.nodeFrames["A"])
        let finishFrame = try #require(layout.nodeFrames["B"])

        #expect(startFrame.minY > finishFrame.minY)
    }

    @MainActor
    @Test func mermaidLayoutHonorsRightLeftDirection() async throws {
        let flowchart = try #require(MermaidFlowchartParser.parse("""
        flowchart RL
            A[Start] --> B[Finish]
        """))
        let layout = MermaidFlowchartLayoutEngine.layout(flowchart)

        let startFrame = try #require(layout.nodeFrames["A"])
        let finishFrame = try #require(layout.nodeFrames["B"])

        #expect(startFrame.minX > finishFrame.minX)
    }

    @MainActor
    @Test func previewBlockParserSeparatesMermaidFenceFromMarkdown() async throws {
        let markdown = """
        # Title

        ```mermaid
        \(sampleMermaidFlowchart)
        ```

        After diagram.
        """

        let blocks = MarkdownPreviewBlockParser.parse(markdown)

        #expect(blocks.count == 3)
        guard case .markdown(let title) = blocks[0] else {
            Issue.record("First block should be Markdown")
            return
        }
        guard case .mermaid(let source) = blocks[1] else {
            Issue.record("Second block should be Mermaid")
            return
        }
        guard case .markdown(let tail) = blocks[2] else {
            Issue.record("Third block should be Markdown")
            return
        }

        #expect(title.contains("# Title"))
        #expect(source.contains("flowchart TD"))
        #expect(tail.contains("After diagram."))
    }

    @MainActor
    @Test func previewBlockParserSeparatesMarkdownTableFromSurroundingText() async throws {
        let markdown = """
        # Dependencies

        \(sampleLongMarkdownTable)

        After table.
        """

        let blocks = MarkdownPreviewBlockParser.parse(markdown)

        #expect(blocks.count == 3)
        guard case .markdown(let title) = blocks[0] else {
            Issue.record("First block should be Markdown")
            return
        }
        guard case .table(let table) = blocks[1] else {
            Issue.record("Second block should be a Markdown table")
            return
        }
        guard case .markdown(let tail) = blocks[2] else {
            Issue.record("Third block should be Markdown")
            return
        }

        #expect(title.contains("# Dependencies"))
        #expect(table.headers == ["类型", "文档或风险", "处理"])
        #expect(table.rows.count == 12)
        #expect(table.rows[9][1] == "`MossCode Route` 具体结构需要三端共同评审")
        #expect(tail.contains("After table."))
    }

    @MainActor
    @Test func advancedMermaidSampleResourceExistsParsesAndIsDesensitized() async throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceURL = projectURL
            .appendingPathComponent("MarkdownDemo")
            .appendingPathComponent("Resources")
            .appendingPathComponent("TestCases")
            .appendingPathComponent("Advanced")
            .appendingPathComponent("06_Mermaid流程图.md")

        let content = try String(contentsOf: resourceURL, encoding: .utf8)
        #expect(content.contains("title: \"Mermaid 流程图\""))
        #expect(content.contains("category: \"advanced\""))
        #expect(content.contains("```mermaid"))

        for sensitiveTerm in ["路线", "PRD", "MossCode", "PHI", "地图", "Segment", "POI", "Action", "Strava", "Komoot"] {
            #expect(!content.contains(sensitiveTerm))
        }

        let blocks = MarkdownPreviewBlockParser.parse(markdownBody(from: content))
        let mermaidSources = blocks.compactMap { block -> String? in
            if case .mermaid(let source) = block {
                return source
            }
            return nil
        }
        let source = try #require(mermaidSources.first)
        let flowchart = try #require(MermaidFlowchartParser.parse(source))

        #expect(flowchart.direction == .topDown)
        #expect(flowchart.nodes.count >= 6)
        #expect(flowchart.edges.contains { $0.label == "系统标签" })
        #expect(flowchart.edges.contains { $0.label == "自定义标签" })
    }

    private func markdownBody(from content: String) -> String {
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else {
            return content
        }
        return parts.dropFirst(2)
            .joined(separator: "---")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
