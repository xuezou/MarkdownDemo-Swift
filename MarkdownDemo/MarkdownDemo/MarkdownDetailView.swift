//
//  MarkdownDetailView.swift
//  MarkdownDemo
//

import SwiftUI

/// Markdown 渲染详情视图
struct MarkdownDetailView: View {
    let testCase: MarkdownTestCase
    let category: TestCategory
    
    @State private var selectedTab = 0
    
    var color: Color {
        Color.fromString(category.color)
    }
    
    // 计算渲染后的文本
    private var renderedContent: AttributedString {
        MarkdownRenderer.render(markdown: testCase.markdown)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 案例信息卡片
                CaseInfoCard(testCase: testCase, category: category)
                
                // 内容标签切换
                Picker("视图", selection: $selectedTab) {
                    Text("渲染效果").tag(0)
                    Text("原始 Markdown").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 内容区域
                Group {
                    if selectedTab == 0 {
                        RenderedContentView(
                            content: renderedContent,
                            expectedFeatures: testCase.expectedFeatures,
                            color: color
                        )
                    } else {
                        RawMarkdownView(content: testCase.markdown)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(testCase.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        selectedTab = selectedTab == 0 ? 1 : 0
                    }
                } label: {
                    Image(systemName: selectedTab == 0 ? "doc.plaintext" : "eye")
                }
            }
        }
    }
}

// MARK: - 子视图

/// 案例信息卡片
private struct CaseInfoCard: View {
    let testCase: MarkdownTestCase
    let category: TestCategory
    
    var color: Color {
        Color.fromString(category.color)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(testCase.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                CategoryBadge(category: category)
            }
            
            Divider()
            
            // 描述
            Text(testCase.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // 文件信息
            HStack {
                Image(systemName: "doc")
                    .font(.caption)
                Text(testCase.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // 预期功能标签
            VStack(alignment: .leading, spacing: 8) {
                Text("预期渲染特性")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(testCase.expectedFeatures, id: \.self) { feature in
                        FeatureTag(text: feature, color: color)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8)
        .padding(.horizontal)
    }
}

/// 类别徽章
private struct CategoryBadge: View {
    let category: TestCategory
    
    var color: Color {
        Color.fromString(category.color)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
            Text(category.name)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

/// 功能标签
private struct FeatureTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundColor(color.opacity(0.9))
            .cornerRadius(6)
    }
}

/// 渲染内容视图
private struct RenderedContentView: View {
    let content: AttributedString
    let expectedFeatures: [String]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 渲染效果标签
            Label("渲染效果", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // 渲染结果
            VStack(alignment: .leading, spacing: 0) {
                // 深色背景容器
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.9))
                    
                    ScrollView {
                        Text(content)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minHeight: 200)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // 渲染统计
            RenderStatsView(content: content)
        }
    }
}

/// 渲染统计视图
private struct RenderStatsView: View {
    let content: AttributedString
    
    var body: some View {
        HStack(spacing: 16) {
            StatItemView(
                icon: "character",
                value: "\(content.characters.count)",
                label: "字符数"
            )
            
            StatItemView(
                icon: "text.quote",
                value: "\(content.characters.filter { $0 == Character("\n") }.count + 1)",
                label: "行数"
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// 统计项视图
private struct StatItemView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 原始 Markdown 视图
private struct RawMarkdownView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("原始 Markdown", systemImage: "doc.plaintext")
                .font(.headline)
                .foregroundStyle(.primary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(minHeight: 200)
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }
    
    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Color Extension

#Preview("详情视图") {
    NavigationStack {
        MarkdownDetailView(
            testCase: MarkdownTestCase(
                id: UUID(),
                fileName: "test.md",
                title: "示例测试",
                description: "这是一个测试案例",
                category: "basic",
                markdown: "# 标题\\n\\n这是正文",
                expectedFeatures: ["标题", "正文"]
            ),
            category: TestCategory(
                id: "basic",
                name: "基础格式",
                icon: "textformat",
                color: "blue",
                description: "",
                cases: []
            )
        )
    }
}
