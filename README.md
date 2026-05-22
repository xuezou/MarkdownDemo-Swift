# iOS 自定义 Markdown 渲染实践：从成品库到可魔改 Demo

如果你的 Markdown 渲染需求比较常规，比如标题、列表、引用、代码块、图片、链接等基础能力，建议优先尝试更成熟的成品库，例如 `swift-markdown-ui`。这类库已经处理了大量边界情况，接入成本低，也更适合快速上线。

但如果你的需求比较“非标准”，例如：

- 自定义字体、颜色、间距
- 深度适配产品 UI 风格
- 对表格、引用、代码块做特殊样式
- 支持自定义语法
- 支持类 LaTeX 公式
- 需要控制每一种 Markdown block 的渲染方式

那就可以参考这个 demo 的思路，自己做一套可魔改的 Markdown 渲染器。

---

## 一、整体思路

这个 demo 的核心不是做一个完整 Markdown 标准实现，而是实现一个“够用且可控”的渲染管线。

整体流程大概是：

```swift
Markdown 文本
   ↓
预处理特殊语法，比如 LaTeX
   ↓
按 block 分割内容
   ↓
识别 block 类型
   ↓
分别渲染标题、段落、列表、代码块、表格、引用等
   ↓
输出 AttributedString
   ↓
SwiftUI Text 展示
```

核心入口类似：

```swift
static func render(markdown: String) -> AttributedString {
    let (processedMarkdown, formulas) = preprocessLaTeX(markdown)
    let blocks = splitIntoBlocks(processedMarkdown)

    var result = AttributedString()

    for block in blocks {
        let renderedBlock = renderBlock(block, formulas: formulas)
        result += renderedBlock
        result += AttributedString("\n\n")
    }

    return result
}
```

这种方式的优点是简单、直接、可控。

缺点也很明显：它不是完整 Markdown parser，复杂嵌套、HTML、图片、任务列表等能力需要逐步补。

---

## 二、为什么不用纯 `AttributedString(markdown:)`

iOS 原生的 `AttributedString(markdown:)` 很方便，但它更适合行内 Markdown，例如：

```markdown
这是 **加粗**，这是 *斜体*，这是 `code`
```

如果你想控制整块内容，比如：

- 标题字体大小
- 代码块背景
- 引用块样式
- 表格排版
- LaTeX 公式展示

仅靠系统 Markdown 解析就不够灵活了。

所以 demo 采用了一个折中方案：

- block 级别自己解析
- inline 级别交给 `AttributedString(markdown:)`
- 特殊语法自己预处理

这样既不用从零实现全部 Markdown，又能保留足够的自定义空间。

---

## 三、Block 级解析

demo 里先通过空行把 Markdown 分成多个 block：

```swift
private static func splitIntoBlocks(_ markdown: String) -> [String]
```

然后根据内容判断 block 类型：

```swift
if trimmed.hasPrefix("```") {
    return renderCodeBlock(trimmed)
}

if isOrderedList(trimmed) {
    return renderOrderedList(trimmed, formulas: formulas)
}

if isUnorderedList(trimmed) {
    return renderUnorderedList(trimmed, formulas: formulas)
}

if isTable(trimmed) {
    return renderTableBlock(trimmed, formulas: formulas)
}

if trimmed.hasPrefix(">") {
    return renderBlockQuote(trimmed, formulas: formulas)
}

if let headingLevel = detectHeadingLevel(trimmed) {
    return renderHeading(trimmed, level: headingLevel, formulas: formulas)
}

return renderParagraph(trimmed, formulas: formulas)
```

这种写法非常适合 demo 或产品内定制场景。

你可以很轻松地加新规则，例如：

```swift
if trimmed.hasPrefix("::: warning") {
    return renderWarningBlock(trimmed)
}
```

这就是自定义渲染器最大的价值：产品想要什么语法，就加什么语法。

---

## 四、标题渲染

标题渲染逻辑一般包括两步：

1. 去掉 Markdown 标记，比如 `##`
2. 应用自定义字号和字体

示例：

```swift
private static func renderHeading(
    _ text: String,
    level: Int,
    formulas: [String: LaTeXFormula]
) -> AttributedString {
    var content = text.trimmingCharacters(in: .whitespaces)

    let prefix = String(repeating: "#", count: level)
    if content.hasPrefix(prefix) {
        content = String(content.dropFirst(level))
            .trimmingCharacters(in: .whitespaces)
    }

    let attr = parseInlineMarkdown(content, formulas: formulas)

    var styled = AttributedString()
    for run in attr.runs {
        var runAttr = AttributedString(attr[run.range])
        runAttr.font = .misans(.semibold, size: fontSize)
        runAttr.foregroundColor = .white
        styled.append(runAttr)
    }

    return styled
}
```

这样可以完全控制不同级别标题的字号、字重和颜色。

---

## 五、列表渲染

无序列表可以通过前缀判断：

```swift
- item
* item
+ item
```

渲染时自己插入项目符号：

```swift
var bullet = AttributedString("• ")
bullet.foregroundColor = .white
bullet.font = .misans(.medium, size: 16)

result.append(bullet)
result.append(itemContent)
```

有序列表则用正则识别：

```swift
let pattern = "^(\\d+)[.)]\\s"
```

这里有个细节：`NSRegularExpression` 返回的是 `NSRange`，而 Swift String 不能直接用整数下标切片，需要转成 `String.Index`：

```swift
let matchRange = Range(match.range, in: trimmed)
let afterNumber = String(trimmed[matchRange.upperBound...])
```

否则在新版本 Swift 里容易直接编译失败。

---

## 六、代码块与表格

代码块可以先去掉前后的 ```，再应用等宽字体和背景色：

```swift
var codeAttr = AttributedString(codeContent)
codeAttr.font = .misans(.medium, size: 14)
codeAttr.foregroundColor = .gray
codeAttr.backgroundColor = .gray.opacity(0.1)
```

表格则可以先按行拆分，再按 `|` 拆 cell。

这个 demo 里的表格渲染是比较轻量的文本表格方案，适合验证效果。如果产品里表格很重要，建议改成 SwiftUI View 级渲染，而不是塞进一个 `AttributedString`。

---

## 七、LaTeX 公式支持

这次 demo 里还加入了类 LaTeX 公式支持。

支持几种常见写法：

```latex
\(E = mc^2\)
```

```latex
\[
330 \text{kcal} + 10 \text{kcal} = 340 \text{kcal}
\]
```

```latex
$$
\frac{1}{2} + \frac{1}{3} = \frac{5}{6}
$$
```

实现思路是：

1. 预处理 Markdown
2. 把公式替换成安全占位符
3. 正常走 Markdown 渲染
4. 最后把占位符替换成公式文本

注意，占位符不要写成：

```text
[[LATEX_0]]
```

因为它很容易被 Markdown 解析器当成链接或特殊 bracket 语法处理。

更安全的是使用纯文本 token，例如：

```text
LATEXFORMULATOKEN0END
```

LaTeX 内容再做简单转换：

```swift
\text{kcal}  -> kcal
\frac{1}{2}  -> 1⁄2
\sqrt{x}     -> √(x)
\pm          -> ±
\theta       -> θ
x^2          -> x²
x_i          -> xᵢ
```

这不是完整 LaTeX 引擎，但对很多产品里的“数学表达式展示”已经足够。

如果你需要真正的公式排版，比如分式上下结构、根号拉伸、矩阵、对齐公式，建议后续接入 KaTeX/MathJax 渲染图片，或者使用 WebView/第三方公式渲染方案。

---

## 八、资源文件加载的小坑

这个 demo 还有一个很典型的坑：Markdown 测试文件放在工程目录里，但运行时不一定保持原来的目录结构。

比如源文件是：

```text
Resources/TestCases/Special/05_数学公式.md
```

但 Xcode 打包后可能被拷贝到 app bundle 根目录：

```text
MarkdownDemo.app/05_数学公式.md
```

所以加载逻辑不能只找：

```text
TestCases/Special
Resources/TestCases/Special
```

还需要递归扫描 bundle 里的 `.md` 文件，并从 front matter 读取分类：

```yaml
---
title: "数学公式"
description: "测试数学公式格式化"
category: "special"
---
```

这样无论 Xcode 怎么拷资源，都能正常加载。

---

## 九、SwiftUI 状态更新注意点

还有一个小问题：

```swift
private var renderedContent: AttributedString {
    if let cached = renderedText {
        return cached
    }
    let result = MarkdownRenderer.render(markdown: testCase.markdown)
    renderedText = result
    return result
}
```

这种写法会在 View 更新过程中修改 `@State`，触发：

```text
Modifying state during view update, this will cause undefined behavior.
```

更稳妥的方式是 computed property 里不要写状态：

```swift
private var renderedContent: AttributedString {
    MarkdownRenderer.render(markdown: testCase.markdown)
}
```

如果后续渲染成本变高，可以改成 `task`、`onAppear` 或者 ViewModel 缓存。

---

## 十、适合自定义渲染的场景

这个 demo 的方案适合：

- 文档内容来源可控
- Markdown 语法范围可控
- UI 样式高度定制
- 需要支持少量自定义语法
- 需要和产品设计深度融合

不太适合：

- 完整 GitHub Flavored Markdown
- 复杂 HTML 混排
- 图片、脚注、TOC、任务列表全量支持
- 高精度数学公式排版
- 大文档高性能滚动排版

如果只是展示普通 Markdown 文档，用成熟库更划算。

如果产品希望 Markdown 渲染长得“像自己家的东西”，那就可以沿着这个 demo 的方向继续魔改。

---

## 总结

iOS 上做自定义 Markdown 渲染，可以不用一上来就写完整 parser。

一个实用的中间方案是：

- block 自己解析
- inline 使用 `AttributedString(markdown:)`
- 特殊语法通过预处理解决
- 最终统一输出 `AttributedString` 或 SwiftUI View

这套方案的优势是灵活、轻量、好改。

对于自定义需求不高的项目，优先选择 `swift-markdown-ui` 这类成熟库。  
对于自定义需求很高的项目，可以参考这个 demo，从标题、列表、代码块、表格、公式这些核心能力开始，一点点把 Markdown 渲染器改造成适合自己产品的版本。
