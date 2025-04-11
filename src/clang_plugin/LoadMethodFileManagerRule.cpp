#include "LoadMethodFileManagerRule.h"
#include "clang/AST/DeclObjC.h" // For ObjCMethodDecl
#include "clang/AST/ExprObjC.h" // For ObjCMessageExpr
#include "clang/Basic/IdentifierTable.h" // For creating Selectors

namespace launchguard {

LoadMethodFileManagerRule::LoadMethodFileManagerRule(clang::CompilerInstance &CI)
    : DiagnosticRule(CI) {}

llvm::StringRef LoadMethodFileManagerRule::getName() const {
    return "LoadMethodFileManagerRule";
}

// 初始化时，创建我们关心的 NSFileManager 方法的选择器
void LoadMethodFileManagerRule::initialize() {
    // 获取 SelectorTable 用于创建 Selector
    clang::IdentifierTable &Idents = Context.Idents;
    clang::SelectorTable &Selectors = Context.Selectors;

    // fileExistsAtPath:
    llvm::StringRef fileExistsAtPathSelName = "fileExistsAtPath:";
    targetSelectors.push_back(Selectors.getUnarySelector(&Idents.get(fileExistsAtPathSelName)));

    // createDirectoryAtPath:withIntermediateDirectories:attributes:error:
    llvm::StringRef createDirSelName[] = {"createDirectoryAtPath", "withIntermediateDirectories", "attributes", "error"};
    targetSelectors.push_back(Selectors.getSelector(4, &Idents.get(createDirSelName[0]))); // 需要传递参数数量和第一个标识符的指针

    // 你可以在这里添加更多 NSFileManager 的方法选择器
}

bool LoadMethodFileManagerRule::visitObjCMethodDecl(clang::ObjCMethodDecl *D) {
    // 检查当前方法是否是 +load
    if (D && D->isClassMethod() && D->getSelector().getAsString() == "load") {
        isInLoadMethod = true;
        // llvm::outs() << "Entering +load method: " << D->getQualifiedNameAsString() << "\n";
    } else {
         // 如果不是 +load，重置标记（处理嵌套定义等情况，尽管不常见）
         // 一个更健壮的方法是使用栈来管理 isInLoadMethod 状态，但对于非嵌套场景，简单标记足够
        // 注意：这里简化处理，假设 visitObjCMethodDecl 会在进入方法体前调用，
        // 离开方法体后需要一种机制重置 isInLoadMethod。
        // RecursiveASTVisitor 通常会在访问完一个 Decl 后自动回溯，
        // 但为了明确，我们可以在 VisitStmt 等节点判断父节点来管理状态，或者依赖于
        // RecursiveASTVisitor 对 Decl 访问的顺序。
        // 一个简单的技巧是：在 visitObjCMessageExpr 中检查其父 Decl 是否是 +load。
        // 这里暂时保留 isInLoadMethod 标记，依赖于分发顺序。
    }
    return true; // 继续访问子节点
}

bool LoadMethodFileManagerRule::visitObjCMessageExpr(clang::ObjCMessageExpr *E) {
    // 首先检查是否在 +load 方法内
    // 更可靠的方式：检查调用所在的父方法声明
    clang::ObjCMethodDecl* parentMethod = E->getAncestorOfType<clang::ObjCMethodDecl>();
    if (!parentMethod || !parentMethod->isClassMethod() || parentMethod->getSelector().getAsString() != "load") {
        return true; // 不在 +load 方法内，跳过
    }

    // 检查消息接收者是否是 NSFileManager
    const clang::ObjCInterfaceDecl *receiverDecl = E->getReceiverInterface();
    if (!receiverDecl || receiverDecl->getNameAsString() != "NSFileManager") {
        // 也可能通过实例调用，检查类型
        if (E->getReceiverKind() == clang::ObjCMessageExpr::Instance) {
             clang::QualType receiverType = E->getInstanceReceiver()->getType();
             const clang::ObjCObjectPointerType *ptrType = receiverType->getAs<clang::ObjCObjectPointerType>();
             if (!ptrType || !ptrType->getInterfaceDecl() || ptrType->getInterfaceDecl()->getNameAsString() != "NSFileManager") {
                 return true; // 接收者不是 NSFileManager
             }
        } else {
            return true; // 接收者不是类或实例
        }
    }

    // 检查选择器是否匹配目标列表中的任何一个
    clang::Selector calledSelector = E->getSelector();
    for (const auto& targetSelector : targetSelectors) {
        if (calledSelector == targetSelector) {
            std::string message = "在 +load 方法中调用 NSFileManager 的方法 '";
            message += calledSelector.getAsString();
            message += "' 可能导致启动性能问题。";
            reportWarning(E->getExprLoc(), message);
            break; // 找到匹配项，无需继续检查其他目标选择器
        }
    }

    return true; // 继续访问子节点
}

} // namespace launchguard 