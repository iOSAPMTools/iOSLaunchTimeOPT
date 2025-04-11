// CustomRules.swift (放置在 SwiftLint 能找到的自定义规则目录下)
import SwiftSyntax
import SwiftLintFramework // 需要引入 SwiftLintFramework

// --- 黑名单 API (改进为更结构化的表示) ---
// Key: 可能的 Base Name (类名/模块名/全局函数)
// Value: Set of method/property names (不含参数标签，简化处理)
private let expensiveAPIs: [String: Set<String>] = [
    "Data": ["init"], // 简化：只关心 Data.init(...)，但无法精确区分参数
    "CryptoHelper": ["performExpensiveSyncOperation"]
]

// 辅助函数：尝试从表达式解析出 Base 和 Name
private func extractCallInfo(_ node: ExprSyntax) -> (base: String?, name: String)? {
    if let callExpr = node.as(FunctionCallExprSyntax.self) {
        return extractCallInfo(callExpr.calledExpression) // 递归查找被调用表达式
    } else if let memberAccessExpr = node.as(MemberAccessExprSyntax.self) {
        let name = memberAccessExpr.declName.baseName.text // 获取方法/属性名
        // 尝试获取 base 名称 (可能需要递归)
        var currentBase: ExprSyntax? = memberAccessExpr.base
        while let nextMemberAccess = currentBase?.as(MemberAccessExprSyntax.self) {
            currentBase = nextMemberAccess.base
        }
        let base = currentBase?.as(DeclReferenceExprSyntax.self)?.baseName.text // 获取最底层的标识符
        return (base: base, name: name)
    } else if let identifierExpr = node.as(DeclReferenceExprSyntax.self) {
        let name = identifierExpr.baseName.text
        // 可能是全局函数调用或省略 self 的实例方法调用
        // 无法轻易确定 base，返回 nil base
        return (base: nil, name: name)
    }
    return nil
}

// --- 规则 1: ExpensiveInitializerRule ---
struct ExpensiveInitializerRule: ConfigurationProviderRule, SwiftSyntaxRule {
    var configuration = SeverityConfiguration(.warning) // 规则严重级别

    static let description = RuleDescription(
        identifier: "expensive_initializer",
        name: "Expensive Initializer",
        description: "Avoid potentially expensive API calls in global/static initializers.",
        kind: .performance, // 规则分类
        nonTriggeringExamples: [
            Example("let globalValue = 10"),
            Example("static let shared = MyManager()"),
            Example("lazy var lazyValue = { computeValue() }()") // lazy 初始化通常没问题
        ],
        triggeringExamples: [
            Example("let globalData = try? ↓Data(contentsOf: url)"), // 触发 (改进后应更精确)
            Example("static let cryptoResult = ↓CryptoHelper.performExpensiveSyncOperation()"), // 触发
            Example("let complexValue: Int = { let x = 1; return ↓CryptoHelper.performExpensiveSyncOperation() + x }()") // 闭包内触发
        ]
    )

    // 使用 SyntaxVisitor 遍历 AST
    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }

    // Visitor 类，实际执行检查
    private final class Visitor: ViolationsSyntaxVisitor {
        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            // 检查是否是全局 (无父节点?) 或静态变量
            let isGlobal = node.parent is SourceFileSyntax // 简化判断全局
            let isStatic = node.modifiers?.contains(where: { $0.name.tokenKind == .keyword(.static) }) ?? false

            guard isGlobal || isStatic else { return .visitChildren } // 不是全局或静态，不检查

            // 检查初始化器
            for binding in node.bindings {
                if let initializer = binding.initializer {
                    // 使用 *改进后* 的 CallExprVisitor
                    let callVisitor = CallExprVisitor(viewMode: .sourceAccurate)
                    callVisitor.walk(initializer.value)
                    for violationPos in callVisitor.violationPositions {
                         violations.append(violationPos) // 直接添加位置
                    }
                }
            }
            return .visitChildren // 继续访问子节点
        }
    }

    // 用于查找函数调用的辅助 Visitor
    private final class CallExprVisitor: ViolationsSyntaxVisitor {
        var violationPositions: [AbsolutePosition] = [] // 只记录位置

         override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
             if let (base, name) = extractCallInfo(node.calledExpression) {
                 // 检查 Base
                 if let baseName = base, let methods = expensiveAPIs[baseName], methods.contains(name) {
                     violationPositions.append(node.positionAfterSkippingLeadingTrivia)
                 }
                 // 检查无 Base 的情况 (例如全局函数，或无法解析 Base 的情况)
                 // 这里简化：如果 base 为 nil，也检查是否直接匹配黑名单 key (作为函数名)
                 else if base == nil, let methods = expensiveAPIs[name], methods.isEmpty { // 假设黑名单中全局函数没有方法名
                    // 这部分逻辑需要根据实际黑名单调整
                 }
             }
             return .visitChildren
         }

         // 对于 MemberAccessExpr，主要关心它是否被 FunctionCallExpr 调用
         // 单独访问 MemberAccessExpr 可能导致误报 (例如只是引用方法但未调用)
         // 所以主要检查逻辑放在 visit(FunctionCallExprSyntax) 中
         // 如果需要检查属性访问，则在此处添加逻辑
         override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
             // 示例：如果黑名单包含属性访问，可以在这里检查
             // let baseName = node.base?.description ?? "" // 简化获取 base
             // let memberName = node.name.text
             // if baseName == "SomeClass" && memberName == "expensiveProperty" ...
             return .visitChildren
         }
    }
}


// --- 规则 2: ExpensiveInitMethodRule ---
struct ExpensiveInitMethodRule: ConfigurationProviderRule, SwiftSyntaxRule {
    var configuration = SeverityConfiguration(.warning)

    static let description = RuleDescription(
        identifier: "expensive_init_method",
        name: "Expensive Init Method",
        description: "Avoid potentially expensive API calls directly inside init methods.",
        kind: .performance,
        nonTriggeringExamples: [
            Example("""
            class MyClass {
                let prop: Int
                init(value: Int) {
                    self.prop = value // Simple assignment
                }
            }
            """)
        ],
        triggeringExamples: [
            Example("""
            class MyClass {
                init() {
                    let data = try? ↓Data(contentsOf: url) // Trigger
                }
            }
            """),
            Example("""
            struct MyStruct {
                init?() {
                    guard let result = ↓CryptoHelper.performExpensiveSyncOperation() else { return nil } // Trigger
                }
            }
            """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }

     // Visitor 查找 init 方法并检查其内部调用
     private final class Visitor: ViolationsSyntaxVisitor {
         override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
             // 进入了 init 方法，现在检查其内部的函数调用
             if let body = node.body {
                 // 使用 *改进后* 的 CallExprVisitor
                 let callVisitor = CallExprVisitor(viewMode: .sourceAccurate)
                 callVisitor.walk(body)
                 for violationPos in callVisitor.violationPositions {
                    // 报告违规，可以添加更具体的 reason
                    let reason = "Potential expensive API call found in init method."
                     violations.append(ReasonedRuleViolation(position: violationPos, reason: reason, ruleDescription: ExpensiveInitMethodRule.description))
                 }
             }
             return .visitChildren // 继续访问子节点
         }
     }

     // 与 ExpensiveInitializerRule 共用相同的 CallExprVisitor
     private final class CallExprVisitor: ViolationsSyntaxVisitor {
        var violationPositions: [AbsolutePosition] = []

         override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
             if let (base, name) = extractCallInfo(node.calledExpression) {
                 if let baseName = base, let methods = expensiveAPIs[baseName], methods.contains(name) {
                     violationPositions.append(node.positionAfterSkippingLeadingTrivia)
                 }
                 // ... (处理无 base 情况) ...
             }
             return .visitChildren
         }
         override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            let fullAccess = node.description.trimmingCharacters(in: .whitespacesAndNewlines)
             for expensiveCall in expensiveAPIs.values.flatMap({ $0 }) {
                  if fullAccess.contains(expensiveCall) {
                      // 检查是否在函数调用上下文中？这里简化，只要访问就告警
                      violationPositions.append(node.positionAfterSkippingLeadingTrivia)
                  }
             }
             return .visitChildren
         }
     }
}