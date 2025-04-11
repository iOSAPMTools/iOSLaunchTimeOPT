#ifndef LAUNCH_GUARD_PLUGIN_DIAGNOSTIC_RULE_H
#define LAUNCH_GUARD_PLUGIN_DIAGNOSTIC_RULE_H

#include "clang/AST/ASTConsumer.h"
#include "clang/AST/Decl.h"          // 基类声明，如 FunctionDecl, ObjCMethodDecl
#include "clang/AST/Expr.h"          // 表达式，如 CallExpr, ObjCMessageExpr
#include "clang/AST/Stmt.h"          // 语句
#include "clang/AST/RecursiveASTVisitor.h" // 用于遍历 AST
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Sema/Sema.h"         // 用于报告诊断信息
#include "llvm/ADT/StringRef.h"

namespace launchguard {

// 前向声明
class RuleBasedASTVisitor;

/**
 * @brief 诊断规则的抽象基类。
 * 所有具体的检查规则都应继承此类并实现检查逻辑。
 */
class DiagnosticRule {
public:
    // 构造函数，接收 CompilerInstance 用于报告诊断
    explicit DiagnosticRule(clang::CompilerInstance &CI)
        : CI(CI), Context(CI.getASTContext()), Diags(CI.getDiagnostics()) {}

    virtual ~DiagnosticRule() = default;

    // ---- 需要被子类实现的接口 ----

    /**
     * @brief 返回规则的唯一名称/标识符。
     */
    virtual llvm::StringRef getName() const = 0;

    /**
     * @brief 在 AST 遍历开始前调用，可以进行一些初始化。
     */
    virtual void initialize() {}

    /**
     * @brief 在 AST 遍历结束后调用，可以进行一些清理或总结。
     */
    virtual void finalize() {}

    /**
     * @brief 访问 Objective-C 方法定义。
     * 子类可以重写此方法来检查特定的方法，例如 +load。
     * @param D The Objective-C method declaration node.
     * @return true 继续访问子节点, false 停止访问此节点的子节点。
     */
    virtual bool visitObjCMethodDecl(clang::ObjCMethodDecl *D) { return true; }

    /**
     * @brief 访问 Objective-C 消息表达式 (方法调用)。
     * 子类可以重写此方法来检查特定的方法调用。
     * @param E The Objective-C message expression node.
     * @return true 继续访问子节点, false 停止访问此节点的子节点。
     */
    virtual bool visitObjCMessageExpr(clang::ObjCMessageExpr *E) { return true; }

    // 可以根据需要添加更多 visit* 方法 (例如 visitFunctionDecl, visitCallExpr, visitVarDecl 等)
    // 参考 clang::RecursiveASTVisitor<Derived> 的接口

protected:
    clang::CompilerInstance &CI;
    clang::ASTContext &Context;
    clang::DiagnosticsEngine &Diags;

    /**
     * @brief 辅助函数，用于报告诊断信息 (警告)。
     * @param Loc 源码位置。
     * @param Message 诊断消息。
     */
    void reportWarning(clang::SourceLocation Loc, const std::string &Message) {
        unsigned DiagID = Diags.getCustomDiagID(clang::DiagnosticsEngine::Warning, Message);
        Diags.Report(Loc, DiagID);
    }

    /**
     * @brief 辅助函数，用于报告诊断信息 (错误)。
     * @param Loc 源码位置。
     * @param Message 诊断消息。
     */
    void reportError(clang::SourceLocation Loc, const std::string &Message) {
        unsigned DiagID = Diags.getCustomDiagID(clang::DiagnosticsEngine::Error, Message);
        Diags.Report(Loc, DiagID);
    }
};

} // namespace launchguard

#endif // LAUNCH_GUARD_PLUGIN_DIAGNOSTIC_RULE_H 