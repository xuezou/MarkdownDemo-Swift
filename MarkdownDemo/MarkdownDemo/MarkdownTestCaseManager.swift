//
//  MarkdownTestCaseManager.swift
//  MarkdownDemo
//

import Foundation
import Combine

/// Markdown 测试案例管理器 - 从资源文件加载测试案例
class MarkdownTestCaseManager: ObservableObject {
    static let shared = MarkdownTestCaseManager()
    
    @Published private(set) var categories: [TestCategory] = []
    @Published private(set) var allCases: [MarkdownTestCase] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        loadAllCases()
    }
    
    /// 重新加载所有测试案例
    func reload() {
        loadAllCases()
    }
    
    /// 类别配置映射
    private let categoryConfigs: [String: CategoryConfig] = [
        "basic": CategoryConfig(name: "基础格式", icon: "textformat", color: "blue", description: "测试 Markdown 基础语法元素"),
        "advanced": CategoryConfig(name: "高级特性", icon: "wand.and.stars", color: "purple", description: "测试 GFM 扩展和复杂排版"),
        "special": CategoryConfig(name: "特殊场景", icon: "sparkles", color: "orange", description: "测试中文、Emoji等特殊内容"),
        "edge": CategoryConfig(name: "边界测试", icon: "exclamationmark.triangle", color: "red", description: "测试极端情况和边界内容"),
        "realworld": CategoryConfig(name: "真实案例", icon: "doc.text", color: "green", description: "真实世界文档模板")
    ]
    
    /// 加载所有测试案例
    private func loadAllCases() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var loadedCategories: [TestCategory] = []
            var loadedCases: [MarkdownTestCase] = []
            
            // 尝试从 Bundle 加载
            if let bundlePath = Bundle.main.resourcePath {
                (loadedCategories, loadedCases) = self.loadFromBundle(path: bundlePath)
            }
            
            // 如果没有加载到任何案例，使用内置备选
            if loadedCases.isEmpty {
                print("⚠️ 未找到资源文件，使用内置测试案例")
                (loadedCategories, loadedCases) = self.loadBuiltInCases()
            }
            
            DispatchQueue.main.async {
                self.categories = loadedCategories
                self.allCases = loadedCases
                self.isLoading = false
                
                if loadedCases.isEmpty {
                    self.errorMessage = "未能加载任何测试案例"
                } else {
                    print("✅ 成功加载 \(loadedCases.count) 个测试案例")
                }
            }
        }
    }
    
    /// 从 Bundle 加载
    private func loadFromBundle(path: String) -> ([TestCategory], [MarkdownTestCase]) {
        var loadedCategories: [TestCategory] = []
        var loadedCases: [MarkdownTestCase] = []
        print("🔎 Bundle resourcePath: \(path)")
        
        let folderMap = [
            ("Basic", "basic"),
            ("Advanced", "advanced"),
            ("Special", "special"),
            ("Edge", "edge"),
            ("RealWorld", "realworld")
        ]
        
        let possiblePaths = ["TestCases", "Resources/TestCases"]
        
        for subPath in possiblePaths {
            let testCasesPath = (path as NSString).appendingPathComponent(subPath)
            guard FileManager.default.fileExists(atPath: testCasesPath) else { continue }
            
            print("✅ 找到 TestCases 目录: \(testCasesPath)")
            
            for (folderName, categoryId) in folderMap {
                let categoryPath = (testCasesPath as NSString).appendingPathComponent(folderName)
                guard FileManager.default.fileExists(atPath: categoryPath) else { continue }
                
                let categoryURL = URL(fileURLWithPath: categoryPath)
                let cases = self.loadCases(from: categoryURL, categoryId: categoryId)
                
                if !cases.isEmpty {
                    let config = categoryConfigs[categoryId] ?? CategoryConfig(name: folderName, icon: "doc.text", color: "gray", description: "")
                    loadedCategories.append(TestCategory(
                        id: categoryId,
                        name: config.name,
                        icon: config.icon,
                        color: config.color,
                        description: config.description,
                        cases: cases
                    ))
                    loadedCases.append(contentsOf: cases)
                }
            }
            
            break // 找到第一个有效路径就退出
        }

        if loadedCases.isEmpty {
            loadedCases = loadFlattenedMarkdownCases(from: path)
            loadedCategories = makeCategories(from: loadedCases)
        }
        
        // 按固定顺序排序
        let orderedIds = ["basic", "advanced", "special", "edge", "realworld"]
        let sortedCategories = orderedIds.compactMap { id in
            loadedCategories.first { $0.id == id }
        }
        
        return (sortedCategories, loadedCases)
    }

    /// Xcode 文件系统同步组会把 .md 资源拷贝到 bundle 根目录；这里兜底递归扫描。
    private func loadFlattenedMarkdownCases(from bundlePath: String) -> [MarkdownTestCase] {
        let bundleURL = URL(fileURLWithPath: bundlePath)
        guard let enumerator = FileManager.default.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let markdownFiles = enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        print("🔎 递归扫描 bundle 中的 Markdown 文件: \(markdownFiles.count)")
        if !markdownFiles.isEmpty {
            print("🔎 示例文件: \(markdownFiles.prefix(5).map(\.lastPathComponent).joined(separator: ", "))")
        }

        return markdownFiles.compactMap { parseCase(from: $0, categoryId: "") }
    }

    private func makeCategories(from cases: [MarkdownTestCase]) -> [TestCategory] {
        let orderedIds = ["basic", "advanced", "special", "edge", "realworld"]
        return orderedIds.compactMap { categoryId in
            let categoryCases = cases.filter { $0.category == categoryId }
            guard !categoryCases.isEmpty else { return nil }

            let config = categoryConfigs[categoryId] ?? CategoryConfig(
                name: categoryId,
                icon: "doc.text",
                color: "gray",
                description: ""
            )

            return TestCategory(
                id: categoryId,
                name: config.name,
                icon: config.icon,
                color: config.color,
                description: config.description,
                cases: categoryCases
            )
        }
    }
    
    /// 内置测试案例（当文件找不到时使用）
    private func loadBuiltInCases() -> ([TestCategory], [MarkdownTestCase]) {
        var categories: [TestCategory] = []
        var allCases: [MarkdownTestCase] = []
        
        // 基础格式测试案例
        let basicCases = [
            MarkdownTestCase(
                id: UUID(),
                fileName: "01_标题层级测试.md",
                title: "标题层级测试",
                description: "测试 H1-H6 六级标题渲染",
                category: "basic",
                markdown: "# 一级标题 (H1)\n## 二级标题 (H2)\n### 三级标题 (H3)\n#### 四级标题 (H4)\n##### 五级标题 (H5)\n###### 六级标题 (H6)",
                expectedFeatures: ["六级标题", "不同字号", "加粗样式"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "02_段落与换行.md",
                title: "段落与换行",
                description: "测试基本段落和换行处理",
                category: "basic",
                markdown: "这是第一个段落。Markdown 是一种轻量级标记语言。\n\n这是第二个段落。段落之间需要空行分隔。\n\n这是第三个段落，包含一些**加粗文字**和*斜体文字*。",
                expectedFeatures: ["段落分隔", "基本文本", "行内格式"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "03_文本样式综合.md",
                title: "文本样式综合",
                description: "加粗、斜体、行内代码等样式",
                category: "basic",
                markdown: "**这是加粗文字**\n\n*这是斜体文字*\n\n***这是加粗斜体***\n\n这是普通文字中混入**加粗**和*斜体*样式。\n\n代码中经常用到 `inline code` 这样的行内代码。",
                expectedFeatures: ["加粗", "斜体", "行内代码"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "04_无序列表.md",
                title: "无序列表",
                description: "测试各种无序列表样式",
                category: "basic",
                markdown: "购物清单：\n\n- 苹果\n- 香蕉\n- 橙子\n- 牛奶\n- 面包",
                expectedFeatures: ["列表项", "项目符号", "层级结构"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "05_有序列表.md",
                title: "有序列表",
                description: "测试数字排序列表",
                category: "basic",
                markdown: "安装步骤：\n\n1. 下载 Xcode\n2. 安装 Command Line Tools\n3. 创建新项目\n4. 配置依赖\n5. 运行项目",
                expectedFeatures: ["数字序号", "顺序排列", "列表项"]
            )
        ]
        
        // 高级特性测试案例
        let advancedCases = [
            MarkdownTestCase(
                id: UUID(),
                fileName: "01_表格渲染.md",
                title: "表格渲染",
                description: "测试 GFM 表格样式",
                category: "advanced",
                markdown: "| 功能 | 支持状态 | 备注 |\n|------|---------|------|\n| 标题 | ✅ | 完全支持 |\n| 列表 | ✅ | 有序和无序 |\n| 表格 | ✅ | GFM 扩展 |",
                expectedFeatures: ["表格结构", "列对齐", "表头样式"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "02_链接样式.md",
                title: "链接样式",
                description: "测试链接和自动链接",
                category: "advanced",
                markdown: "访问 [OpenCode](https://opencode.ai) 了解更多信息。\n\n或者查看 [GitHub](https://github.com) 上的开源项目。\n\n直接链接：https://www.swift.org",
                expectedFeatures: ["超链接", "可点击", "链接颜色"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "03_复杂代码.md",
                title: "复杂代码",
                description: "多层嵌套代码和复杂语法",
                category: "advanced",
                markdown: "## Swift UIKit 代码示例\n\n```swift\nimport UIKit\n\nclass ViewController: UIViewController {\n    \n    private let tableView = UITableView()\n    private var dataSource: [String] = []\n    \n    override func viewDidLoad() {\n        super.viewDidLoad()\n        setupUI()\n        loadData()\n    }\n    \n    private func setupUI() {\n        view.addSubview(tableView)\n        tableView.translatesAutoresizingMaskIntoConstraints = false\n        NSLayoutConstraint.activate([\n            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),\n            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),\n            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),\n            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)\n        ])\n    }\n}\n\n// MARK: - UITableViewDataSource\nextension ViewController: UITableViewDataSource {\n    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {\n        return dataSource.count\n    }\n}\n```\n\n## JSON 数据示例\n\n```json\n{\n    \"users\": [\n        {\n            \"id\": 1,\n            \"name\": \"张三\",\n            \"roles\": [\"admin\", \"editor\"],\n            \"profile\": {\n                \"age\": 28,\n                \"city\": \"北京\",\n                \"hobbies\": [\"游泳\", \"阅读\", \"编程\"]\n            }\n        }\n    ]\n}\n```",
                expectedFeatures: ["语法高亮", "多行代码", "代码缩进"]
            )
        ]
        
        // 特殊场景测试案例
        let specialCases = [
            MarkdownTestCase(
                id: UUID(),
                fileName: "01_中文内容测试.md",
                title: "中文内容测试",
                description: "测试中文字符渲染",
                category: "special",
                markdown: "# 中文排版测试\n\n## 标题与正文\n\n这是一段**中文正文**，用于测试混合*中英文字体*的渲染效果。\n\n### 列表示例\n\n- 第一项：介绍 Swift 语言\n- 第二项：学习 SwiftUI 框架\n- 第三项：`print(\"Hello\")` 代码示例",
                expectedFeatures: ["中文字符", "混合排版", "中文标点"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "02_数学公式.md",
                title: "数学公式",
                description: "测试数学公式格式化",
                category: "special",
                markdown: """
                ## 基础公式

                行内公式：\\(E = mc^2\\) 是最著名的质能方程。

                块级公式：

                \\[
                330 \\text{kcal} + 10 \\text{kcal} + 15.5 \\text{kcal} + 6 \\text{kcal} + 4.7 \\text{kcal} + 14.9 \\text{kcal} + 20 \\text{kcal} = 401.1 \\text{kcal}
                \\]

                美元符号格式也可以：

                $$
                \\frac{1}{2} + \\frac{1}{3} = \\frac{5}{6}
                $$

                ## 数学符号

                ### 希腊字母
                α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω
                Γ Δ Θ Λ Ξ Π Σ Φ Ψ Ω

                ### 上下标
                H₂O 是水的化学式
                x² + y² = r² 是圆的方程

                ### 一元二次方程
                \\[
                x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
                \\]
                """,
                expectedFeatures: ["公式显示", "LaTeX 公式", "特殊符号", "数学排版"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "03_复杂嵌套.md",
                title: "复杂嵌套结构",
                description: "测试多层嵌套的复杂Markdown",
                category: "special",
                markdown: "# 复杂文档结构测试\n\n## 1. 深层嵌套列表\n\n- 一级项目 A\n  - 二级项目 A1\n    - 三级项目 A1a\n      - 四级项目 A1a-i\n        - 五级项目 A1a-i-x\n      - 四级项目 A1a-ii\n    - 三级项目 A1b\n  - 二级项目 A2\n- 一级项目 B\n\n## 2. 列表与元素的混合\n\n### 2.1 列表中的段落\n\n1. 第一项\n   \n   这是第一项的详细说明。可以包含**加粗文字**和*斜体*。\n   \n   还可以有多段内容。\n\n2. 第二项\n   \n   > 甚至可以包含引用块\n   > \n   > 多行引用内容\n\n## 3. 引用块中的复杂内容\n\n> ## 引用中的标题\n> \n> 这是引用块中的普通文字。\n> \n> ### 代码片段\n> ```python\n> def hello():\n>     print(\"Hello from quote!\")\n> ```\n> \n> > 这是嵌套的引用块\n> > 可以继续嵌套\n\n## 4. 混合内容大杂烩\n\n> **重要提示**\n> \n> 1. 请确保完成以下步骤：\n>    - 步骤 A：`command A`\n>    - 步骤 B：`command B`\n>      - 子步骤 1\n>      - 子步骤 2\n> \n> 2. 参考资料：\n>    | 文档 | 链接 |\n>    |------|------|\n>    | API 文档 | [查看](https://example.com) |\n> \n> 感谢使用！🎉",
                expectedFeatures: ["多层嵌套", "混合元素", "复杂结构"]
            )
        ]
        
        // 边界测试案例
        let edgeCases = [
            MarkdownTestCase(
                id: UUID(),
                fileName: "01_边界情况.md",
                title: "边界情况",
                description: "测试极端和边界内容",
                category: "edge",
                markdown: "空行测试：\n\n\n\n上面是空行\n\n超长标题测试：\n\n# 这是一个非常长的标题用于测试长文本在标题中的渲染效果是否会出现截断或者换行问题",
                expectedFeatures: ["长文本处理", "空内容", "特殊空白"]
            ),
            MarkdownTestCase(
                id: UUID(),
                fileName: "02_超长内容.md",
                title: "超长内容测试",
                description: "测试大量内容渲染性能",
                category: "edge",
                markdown: """
                # 长文档性能测试

                这是一个用于测试渲染性能的长文档。

                ## 第1章：简介

                A00引言部分是任何技术文档的关键组成部分。本节提供了项目背景和基本概念的概述。

                ### 1.1 项目背景

                在现代软件开发中，A01良好的文档是不可或缺的。它不仅帮助新成员快速上手，也是维护代码的重要参考。

                A02好的设计原则应该始终贯穿整个开发过程。这意味着在开始编码之前，我们需要充分理解需求并设计合理的架构。

                A03代码可读性同样重要。写代码不仅是给计算机执行的，更是给其他开发者阅读的。

                ### 1.2 核心概念

                A04数据模型是系统的核心。它定义了如何存储和操作数据，直接影响系统的性能和可扩展性。

                A05用户界面设计需要考虑易用性和美观性。一个好的界面应该直观、响应迅速并且视觉愉悦。

                A06API设计应遵循RESTful原则，提供一致的接口规范，方便第三方开发者集成。

                ## 第2章：详细设计

                B00本章深入探讨系统的各个模块设计。

                ### 2.1 架构概览

                B01系统采用微服务架构，服务之间通过消息队列进行通信。这种设计具有良好的扩展性和容错能力。

                B02每个微服务都是独立部署的，可以单独扩展和升级。服务发现使用Consul，配置管理使用Spring Cloud Config。

                B03数据库采用读写分离架构。主数据库处理写操作，多个从数据库处理读操作，通过数据库复制保持数据一致性。

                ### 2.2 模块设计

                B04用户服务负责用户注册、登录、认证和授权。使用JWT token进行身份验证，支持OAuth2.0第三方登录。

                B05订单服务处理订单的创建、支付、发货和售后。与支付服务、库存服务、物流服务进行协调。

                B06商品服务管理商品目录、分类、属性和库存。支持多规格商品和SKU管理。

                ## 第5章：项目列表

                E00以下是一些示例项目内容，用于测试长列表渲染性能。

                - E01 项目编号：P001，名称：用户中心重构
                - E02 项目编号：P002，名称：支付系统升级
                - E03 项目编号：P003，名称：推荐算法优化
                - E04 项目编号：P004，名称：移动端适配
                - E05 项目编号：P005，名称：数据迁移
                - E06 项目编号：P006，名称：安全加固

                ## 第8章：总结

                H00本文档涵盖了项目的各个方面，从背景介绍到部署运维。

                通过以上内容，可以测试 Markdown 渲染器对长文档、表格、代码块等多种元素的渲染性能。

                **注意：** 如果渲染速度过慢，可能需要优化渲染算法或实现虚拟滚动。
                """,
                expectedFeatures: ["性能稳定", "长文本处理", "快速渲染"]
            )
        ]
        
        // 真实案例
        let realWorldCases = [
            MarkdownTestCase(
                id: UUID(),
                fileName: "01_README文档.md",
                title: "README 文档",
                description: "典型的项目 README 结构",
                category: "realworld",
                markdown: "# Project Name\n\n> A brief description of what this project does.\n\n## Features\n\n- Light/dark mode toggle\n- Live previews\n- Fullscreen mode\n\n## Installation\n\n```bash\nnpm install my-project\n```\n\n## License\n\n[MIT](https://choosealicense.com/licenses/mit/)",
                expectedFeatures: ["完整文档", "多章节", "混合内容"]
            )
        ]
        
        // 创建类别
        let basicCategory = TestCategory(
            id: "basic",
            name: "基础格式",
            icon: "textformat",
            color: "blue",
            description: "测试 Markdown 基础语法元素",
            cases: basicCases
        )
        
        let advancedCategory = TestCategory(
            id: "advanced",
            name: "高级特性",
            icon: "wand.and.stars",
            color: "purple",
            description: "测试 GFM 扩展和复杂排版",
            cases: advancedCases
        )
        
        let specialCategory = TestCategory(
            id: "special",
            name: "特殊场景",
            icon: "sparkles",
            color: "orange",
            description: "测试中文、Emoji等特殊内容",
            cases: specialCases
        )
        
        let edgeCategory = TestCategory(
            id: "edge",
            name: "边界测试",
            icon: "exclamationmark.triangle",
            color: "red",
            description: "测试极端情况和边界内容",
            cases: edgeCases
        )
        
        let realWorldCategory = TestCategory(
            id: "realworld",
            name: "真实案例",
            icon: "doc.text",
            color: "green",
            description: "真实世界文档模板",
            cases: realWorldCases
        )
        
        categories = [basicCategory, advancedCategory, specialCategory, edgeCategory, realWorldCategory]
        allCases = basicCases + advancedCases + specialCases + edgeCases + realWorldCases
        
        if !allCases.isEmpty {
            print("✅ 已加载 \(allCases.count) 个内置测试案例")
        }
        
        return (categories, allCases)
    }
    
    /// 加载单个目录下的案例
    private func loadCases(from folderURL: URL, categoryId: String) -> [MarkdownTestCase] {
        var cases: [MarkdownTestCase] = []
        
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return cases
        }
        
        let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
        
        for fileURL in mdFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let testCase = parseCase(from: fileURL, categoryId: categoryId) {
                cases.append(testCase)
            }
        }
        
        return cases
    }
    
    /// 解析测试案例文件
    private func parseCase(from fileURL: URL, categoryId: String) -> MarkdownTestCase? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        
        let (frontMatter, markdown) = extractFrontMatter(from: content)
        
        guard !frontMatter.isEmpty else {
            return nil
        }
        
        let title = parseYAMLValue(from: frontMatter, key: "title") ?? fileURL.deletingPathExtension().lastPathComponent
        let description = parseYAMLValue(from: frontMatter, key: "description") ?? ""
        let category = parseYAMLValue(from: frontMatter, key: "category") ?? categoryId
        let expectedFeatures = parseYAMLArray(from: frontMatter, key: "expectedFeatures")
        
        return MarkdownTestCase(
            id: UUID(),
            fileName: fileURL.lastPathComponent,
            title: title,
            description: description,
            category: category,
            markdown: markdown.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedFeatures: expectedFeatures
        )
    }
    
    /// 提取 Front Matter
    private func extractFrontMatter(from content: String) -> (frontMatter: String, markdown: String) {
        let pattern = "^---\\s*\\n(.*?)\\n---\\s*\\n(.*)$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)) else {
            return ("", content)
        }
        
        let frontMatter = (content as NSString).substring(with: match.range(at: 1))
        let markdown = (content as NSString).substring(with: match.range(at: 2))
        
        return (frontMatter, markdown)
    }
    
    /// 解析 YAML 值
    private func parseYAMLValue(from yaml: String, key: String) -> String? {
        let pattern = "^\\s*\(key)\\s*:\\s*[\"']?(.*?)[\"']?\\s*$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return nil
        }
        
        let matches = regex.matches(in: yaml, options: [], range: NSRange(location: 0, length: yaml.utf16.count))
        guard let match = matches.first else { return nil }
        
        return (yaml as NSString).substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 解析 YAML 数组
    private func parseYAMLArray(from yaml: String, key: String) -> [String] {
        var result: [String] = []
        let lines = yaml.components(separatedBy: .newlines)
        var inArray = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("\(key):") {
                inArray = true
                continue
            }
            
            if inArray {
                if trimmed.hasPrefix("- ") {
                    let value = String(trimmed.dropFirst(2))
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    result.append(value)
                } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    break
                }
            }
        }
        
        return result
    }
}

// MARK: - 数据模型

struct TestCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let description: String
    let cases: [MarkdownTestCase]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MarkdownTestCase: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let title: String
    let description: String
    let category: String
    let markdown: String
    let expectedFeatures: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct CategoryConfig {
    let name: String
    let icon: String
    let color: String
    let description: String
}

// MARK: - 扩展方法

extension MarkdownTestCaseManager {
    func cases(for categoryId: String) -> [MarkdownTestCase] {
        return allCases.filter { $0.category == categoryId }
    }
    
    func searchCases(query: String) -> [MarkdownTestCase] {
        guard !query.isEmpty else { return allCases }
        
        let lowerQuery = query.lowercased()
        return allCases.filter {
            $0.title.lowercased().contains(lowerQuery) ||
            $0.description.lowercased().contains(lowerQuery) ||
            $0.markdown.lowercased().contains(lowerQuery)
        }
    }
}
