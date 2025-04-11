#ifndef LAUNCH_GUARD_PLUGIN_MAIN_THREAD_SYNC_SDK_RULE_H
#define LAUNCH_GUARD_PLUGIN_MAIN_THREAD_SYNC_SDK_RULE_H

#include "DiagnosticRule.h"
#include <string>
#include <vector>

namespace launchguard {

/**
 * @brief 检查是否直接调用了已知的可能在主线程同步耗时的 SDK 方法。
 * 注意：当前版本不进行实际的线程检查，仅匹配方法调用。
 */
class MainThreadSyncSDKRule : public DiagnosticRule {
public:
    explicit MainThreadSyncSDKRule(clang::CompilerInstance &CI);

    llvm::StringRef getName() const override;
    void initialize() override;
    bool visitObjCMessageExpr(clang::ObjCMessageExpr *E) override;

private:
    // 存储目标 SDK 类名和方法选择器
    std::vector<std::pair<std::string, clang::Selector>> targetSDKCalls;
};

} // namespace launchguard

#endif // LAUNCH_GUARD_PLUGIN_MAIN_THREAD_SYNC_SDK_RULE_H 