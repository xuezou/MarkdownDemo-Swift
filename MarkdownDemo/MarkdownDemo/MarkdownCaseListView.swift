//
//  MarkdownCaseListView.swift
//  MarkdownDemo
//

import SwiftUI

/// Markdown 测试案例列表视图
struct MarkdownCaseListView: View {
    @StateObject private var manager = MarkdownTestCaseManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    // 过滤后的案例
    private var filteredCases: [MarkdownTestCase] {
        if let categoryId = selectedCategory {
            return manager.cases(for: categoryId)
        }
        
        if searchText.isEmpty {
            return manager.allCases
        }
        
        return manager.searchCases(query: searchText)
    }
    
    // 按类别分组的案例
    private var groupedCases: [(category: TestCategory, cases: [MarkdownTestCase])] {
        if selectedCategory != nil || !searchText.isEmpty {
            // 如果选择了类别或搜索中，按原类别分组显示
            let grouped = Dictionary(grouping: filteredCases) { $0.category }
            return manager.categories.compactMap { category in
                grouped[category.id].map { (category, $0) }
            }
        }
        
        // 显示所有类别
        return manager.categories.map { ($0, $0.cases) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if manager.isLoading {
                    LoadingView()
                } else if let error = manager.errorMessage {
                    ErrorView(message: error, retryAction: {
                        manager.reload()
                    })
                } else if manager.allCases.isEmpty {
                    EmptyView()
                } else {
                    caseList
                }
            }
            .navigationTitle("Markdown 测试案例")
            .searchable(text: $searchText, prompt: "搜索测试案例")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    categoryMenu
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    reloadButton
                }
            }
        }
    }
    
    /// 案例列表
    private var caseList: some View {
        List {
            // 统计概览
            StatisticsSection(
                totalCases: manager.allCases.count,
                totalCategories: manager.categories.count,
                categories: manager.categories
            )
            
            // 按类别展示案例
            ForEach(groupedCases, id: \.category.id) { category, cases in
                if !cases.isEmpty {
                    Section {
                        ForEach(cases) { testCase in
                            NavigationLink(value: testCase) {
                                CaseRowView(testCase: testCase, category: category)
                            }
                        }
                    } header: {
                        CategoryHeaderView(category: category, count: cases.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: MarkdownTestCase.self) { testCase in
            if let category = manager.categories.first(where: { $0.id == testCase.category }) {
                MarkdownDetailView(testCase: testCase, category: category)
            }
        }
    }
    
    /// 类别菜单
    private var categoryMenu: some View {
        Menu {
            Button("全部显示") {
                selectedCategory = nil
            }
            
            Divider()
            
            ForEach(manager.categories) { category in
                Button(category.name) {
                    selectedCategory = category.id
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(selectedCategory != nil ? .fill : .none)
        }
    }
    
    /// 重新加载按钮
    private var reloadButton: some View {
        Button {
            manager.reload()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(manager.isLoading)
    }
}

// MARK: - Loading & Error Views

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在加载测试案例...")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重新加载", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct EmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("没有找到测试案例")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Statistics Section

private struct StatisticsSection: View {
    let totalCases: Int
    let totalCategories: Int
    let categories: [TestCategory]
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    StatItem(
                        icon: "doc.text",
                        value: "\(totalCases)",
                        label: "测试案例"
                    )
                    
                    Divider()
                    
                    StatItem(
                        icon: "folder",
                        value: "\(totalCategories)",
                        label: "测试类别"
                    )
                }
                .padding(.vertical, 8)
                
                // 类别分布图
                FlowLayout(spacing: 8) {
                    ForEach(categories) { category in
                        CategoryBadge(category: category)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - UI Components

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CategoryBadge: View {
    let category: TestCategory
    
    var color: Color {
        Color.fromString(category.color)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: category.icon)
                .font(.caption)
            
            Text("\(category.cases.count)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

private struct CategoryHeaderView: View {
    let category: TestCategory
    let count: Int
    
    var color: Color {
        Color.fromString(category.color)
    }
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(color)
            
            Text(category.name)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(count) 个案例")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CaseRowView: View {
    let testCase: MarkdownTestCase
    let category: TestCategory
    
    var color: Color {
        Color.fromString(category.color)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(testCase.title)
                    .font(.headline)
                
                Spacer()
                
                // 预期功能标签（只显示前2个）
                HStack(spacing: 4) {
                    ForEach(testCase.expectedFeatures.prefix(2), id: \.self) { feature in
                        Text(feature)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.15))
                            .foregroundColor(color)
                            .cornerRadius(4)
                    }
                }
            }
            
            Text(testCase.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            // 原文预览
            Text(testCase.markdown.prefix(80) + "...")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
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

extension Color {
    static func fromString(_ string: String) -> Color {
        switch string.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "green": return .green
        case "pink": return .pink
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

#Preview("列表视图") {
    MarkdownCaseListView()
}
