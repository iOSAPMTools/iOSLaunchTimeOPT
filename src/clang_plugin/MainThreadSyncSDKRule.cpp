#include "MainThreadSyncSDKRule.h"
#include "clang/AST/DeclObjC.h"
#include "clang/AST/ExprObjC.h"
#include "clang/Basic/IdentifierTable.h"

namespace launchguard {

MainThreadSyncSDKRule::MainThreadSyncSDKRule(clang::CompilerInstance &CI)
    : DiagnosticRule(CI) {}

llvm::StringRef MainThreadSyncSDKRule::getName() const {
    return "MainThreadSyncSDKRule";
}

void MainThreadSyncSDKRule::initialize() {
    clang::IdentifierTable &Idents = Context.Idents;
    clang::SelectorTable &Selectors = Context.Selectors;

    // 添加目标 SDK 调用： [Bugly startWithAppId:]
    llvm::StringRef buglySelName = "startWithAppId:";
    targetSDKCalls.push_back({"Bugly", Selectors.getUnarySelector(&Idents.get(buglySelName))});

    // 你可以在这里添加更多需要监控的 SDK 调用
    // targetSDKCalls.push_back({"SomeOtherSDK", Selectors.getNullarySelector(&Idents.get("initializeBlocking"))});
}

bool MainThreadSyncSDKRule::visitObjCMessageExpr(clang::ObjCMessageExpr *E) {
    // 检查接收者类型和方法选择器
    const clang::ObjCInterfaceDecl *receiverDecl = E->getReceiverInterface();
    if (!receiverDecl) {
        // 可能是实例调用或其他情况，暂时忽略实例调用（如果需要检查实例方法，逻辑类似）
        return true;
    }

    std::string receiverName = receiverDecl->getNameAsString();
    clang::Selector calledSelector = E->getSelector();

    for (const auto& targetCall : targetSDKCalls) {
        if (receiverName == targetCall.first && calledSelector == targetCall.second) {
            std::string message = "检测到调用 '";
            message += targetCall.first; // 类名
            message += (E->isClassMethod() ? " +" : " -"); // 类方法或实例方法
            message += calledSelector.getAsString(); // 方法名
            message += "'。请确认此调用是否发生在主线程，以及是否可能导致性能问题。";
            reportWarning(E->getExprLoc(), message);
            break; // 找到匹配
        }
    }

    return true; // 继续访问子节点
}

} // namespace launchguard 