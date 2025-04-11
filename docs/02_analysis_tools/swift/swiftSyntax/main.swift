// Sources/LaunchGuardSyntaxTool/main.swift
import SwiftSyntax
import SwiftSyntaxParser
import Foundation

// --- 黑名单 API (结构化) ---
// Key: Type Name (e.g., "Data", "CryptoHelper")
// Value: Set of method/function names (e.g., "init", "performExpensiveSyncOperation")
let expensiveAPIs: [String: Set<String>] = [
    "Data": ["init"], // 仍需注意区分参数，例如 contentsOf:
    "CryptoHelper": ["performExpensiveSyncOperation"]
]

// --- AST Visitor ---
class LaunchGuardVisitor: SyntaxVisitor {
    let fileURL: URL
    let converter: SourceLocationConverter

    init(fileURL: URL, tree: SourceFileSyntax) {
        self.fileURL = fileURL
        self.converter = SourceLocationConverter(file: fileURL.path, tree: tree)
        // viewMode: .sourceAccurate 保证访问所有节点
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isGlobal = node.parent is SourceFileSyntax
        let isStatic = node.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })

        guard isGlobal || isStatic else { return .visitChildren }

        for binding in node.bindings {
            if let initializer = binding.initializer {
                // 使用 *改进后* 的 CallExprVisitor
                let callVisitor = CallExprVisitor(viewMode: .sourceAccurate)
                callVisitor.walk(initializer.value)
                for violation in callVisitor.violations {
                     printViolation(at: violation.node.startLocation(converter: converter),
                                    rule: "Expensive Initializer",
                                    call: violation.callDescription)
                }
            }
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if let body = node.body {
            // 使用 *改进后* 的 CallExprVisitor
            let callVisitor = CallExprVisitor(viewMode: .sourceAccurate)
            callVisitor.walk(body)
            for violation in callVisitor.violations {
                 printViolation(at: violation.node.startLocation(converter: converter),
                                rule: "Expensive Init Method",
                                call: violation.callDescription)
            }
        }
        return .visitChildren
    }

    private func printViolation(at location: SourceLocation?, rule: String, call: String) {
        let line = location?.line ?? 0
        let column = location?.column ?? 0
        print("\(fileURL.path):\(line):\(column): warning: [\(rule)] Potential expensive call '\(call)' found.")
    }
}

// --- 辅助 Visitor 查找调用 (改进版) ---
struct CallViolation {
    let node: Syntax // 引发违规的节点 (用于定位)
    let callDescription: String // 违规调用的描述
}

class CallExprVisitor: SyntaxVisitor {
    var violations: [CallViolation] = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // *** 改进的 API 匹配逻辑 ***
        var baseName: String? = nil
        var funcName: String? = nil
        var argumentLabels: [String?] = [] // 尝试获取参数标签

        // 遍历 calledExpression 来解析 base 和 name
        if let calledExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // 情况: base.func() or base.init()
            funcName = calledExpr.declName.baseName.text
            // 尝试解析 Base (可能需要递归)
            var currentBase: ExprSyntax? = calledExpr.base
             while let nextMemberAccess = currentBase?.as(MemberAccessExprSyntax.self) {
                 currentBase = nextMemberAccess.base
             }
            if let baseIdentifier = currentBase?.as(DeclReferenceExprSyntax.self) {
                baseName = baseIdentifier.baseName.text
            } else if let baseIdentifier = currentBase?.as(TypeExprSyntax.self)?.type.as(IdentifierTypeSyntax.self) {
                 baseName = baseIdentifier.name.text // 例如 Data.init
            }
            // else: base 可能是更复杂的表达式，暂时忽略

        } else if let calledExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            // 情况: func() or init() (可能省略了 self 或类型名)
            funcName = calledExpr.baseName.text
            // Base 通常是隐式的 self 或全局，暂时设为 nil
            baseName = nil
        }
        // else: 被调用表达式是其他类型，例如闭包调用，暂时忽略

        // 尝试获取参数标签 (简化)
        for arg in node.arguments {
            argumentLabels.append(arg.label?.text)
        }

        // *** 执行检查 ***
        if let base = baseName, let name = funcName {
            if let methods = expensiveAPIs[base], methods.contains(name) {
                // 这里可以进一步根据 argumentLabels 区分重载，但需要更复杂的黑名单定义
                // 简化：只要类型和方法名匹配就认为是目标
                let desc = "\(base).\(name)(\(argumentLabels.map { $0 ?? "_" }.joined(separator: ":"))\(argumentLabels.isEmpty ? "" : ":"))" // 构造描述
                violations.append(CallViolation(node: Syntax(node), callDescription: desc))
            }
        } else if let name = funcName, baseName == nil {
            // 处理全局函数或省略 self 的情况 (根据黑名单定义调整)
             if let methods = expensiveAPIs[name], methods.isEmpty { // 假设全局函数在黑名单中没有方法名
                 // violations.append(...)
             }
        }

        return .visitChildren
    }

     // MemberAccessExpr 本身不直接报告，除非它是被调用的目标
     // 或者黑名单中包含属性访问
     override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
         // 如果需要检查属性访问，在这里添加逻辑
         return .visitChildren
     }
}

// --- 主程序入口 ---
guard CommandLine.arguments.count > 1 else {
    print("Usage: LaunchGuardSyntaxTool <file_path>")
    exit(1)
}

let filePath = CommandLine.arguments[1]
let fileURL = URL(fileURLWithPath: filePath)

do {
    print("Analyzing file: \(filePath)")
    let sourceFile = try SyntaxParser.parse(fileURL)
    let visitor = LaunchGuardVisitor(fileURL: fileURL, tree: sourceFile) // 传入 URL 和 Tree
    visitor.walk(sourceFile)
    print("Analysis finished.")
} catch {
    print("Error parsing file: \(error)")
    exit(1)
}
