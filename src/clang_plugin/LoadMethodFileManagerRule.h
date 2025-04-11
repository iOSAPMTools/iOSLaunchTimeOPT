#ifndef LAUNCH_GUARD_PLUGIN_LOAD_METHOD_FILEMANAGER_RULE_H
#define LAUNCH_GUARD_PLUGIN_LOAD_METHOD_FILEMANAGER_RULE_H

#include "DiagnosticRule.h"
#include <string>
#include <vector>

namespace launchguard {

/**
 * @brief 检查在 Objective-C +load 方法中调用 NSFileManager 的特定耗时方法。
 */
class LoadMethodFileManagerRule : public DiagnosticRule {
public:
    explicit LoadMethodFileManagerRule(clang::CompilerInstance &CI);

    llvm::StringRef getName() const override;
    void initialize() override; // 用于初始化目标方法选择器
    bool visitObjCMethodDecl(clang::ObjCMethodDecl *D) override;
    bool visitObjCMessageExpr(clang::ObjCMessageExpr *E) override;

private:
    bool isInLoadMethod = false; // 标记当前是否在 +load 方法内部
    // 存储目标方法的选择器 (Selector)
    std::vector<clang::Selector> targetSelectors;
};

} // namespace launchguard

#endif // LAUNCH_GUARD_PLUGIN_LOAD_METHOD_FILEMANAGER_RULE_H 