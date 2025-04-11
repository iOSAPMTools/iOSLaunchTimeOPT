#include "DiagnosticRule.h" // 包含规则基类头文件
#include "LoadMethodFileManagerRule.h"
#include "MainThreadSyncSDKRule.h"
#include "clang/Frontend/FrontendPluginRegistry.h"
#include "clang/AST/ASTConsumer.h"
#include "clang/AST/RecursiveASTVisitor.h"
#include "clang/Frontend/CompilerInstance.h"
#include "llvm/Support/raw_ostream.h" // 用于输出
#include <vector>
#include <memory> // for std::unique_ptr

namespace launchguard {

// ---- 前向声明具体规则类 (不再需要，已包含头文件) ----

// ---- AST Visitor ----
// 使用 RecursiveASTVisitor 遍历 AST，并将节点分发给所有注册的规则
class RuleBasedASTVisitor : public clang::RecursiveASTVisitor<RuleBasedASTVisitor> {
public:
    explicit RuleBasedASTVisitor(clang::CompilerInstance &CI,
                                 std::vector<std::unique_ptr<DiagnosticRule>>& rules)
        : CI(CI), rules(rules) {}

    // 重写需要关注的 visit* 方法，并将节点传递给每个规则
    bool VisitObjCMethodDecl(clang::ObjCMethodDecl *D) {
        bool shouldContinue = true;
        for (auto& rule : rules) {
            if (!rule->visitObjCMethodDecl(D)) {
                shouldContinue = false; // 如果任何规则要求停止，则停止
            }
        }
        return shouldContinue; // 返回 true 继续访问子节点 (除非有规则要求停止)
    }

    bool VisitObjCMessageExpr(clang::ObjCMessageExpr *E) {
         bool shouldContinue = true;
        for (auto& rule : rules) {
            if (!rule->visitObjCMessageExpr(E)) {
                 shouldContinue = false;
            }
        }
        return shouldContinue;
    }

    // 可以添加更多 Visit* 方法来分发其他类型的节点

private:
    clang::CompilerInstance &CI;
    std::vector<std::unique_ptr<DiagnosticRule>>& rules; // 引用规则列表
};

// ---- AST Consumer ----
// 负责创建 Visitor 并遍历 Translation Unit (整个源文件) 的 AST
class LaunchGuardASTConsumer : public clang::ASTConsumer {
public:
    explicit LaunchGuardASTConsumer(clang::CompilerInstance &CI)
        : CI(CI), Visitor(CI, registeredRules) {

        llvm::outs() << "** LaunchGuardPlugin: AST Consumer Created.\n";

        // ---- 在这里注册所有需要启用的规则 ----
        registerRules();

        // 初始化所有规则
        for (auto& rule : registeredRules) {
            rule->initialize();
        }
    }

    ~LaunchGuardASTConsumer() override {
         // 结束所有规则
        for (auto& rule : registeredRules) {
            rule->finalize();
        }
        llvm::outs() << "** LaunchGuardPlugin: AST Consumer Destroyed.\n";
    }

    // 处理顶层声明（整个文件的 AST 入口）
    void HandleTranslationUnit(clang::ASTContext &Context) override {
        llvm::outs() << "** LaunchGuardPlugin: Handling Translation Unit.\n";
        Visitor.TraverseDecl(Context.getTranslationUnitDecl());
        llvm::outs() << "** LaunchGuardPlugin: Finished Handling Translation Unit.\n";
    }

private:
    clang::CompilerInstance &CI;
    std::vector<std::unique_ptr<DiagnosticRule>> registeredRules; // 规则注册表
    RuleBasedASTVisitor Visitor; // AST 遍历器

    // ---- 规则注册函数 ----
    void registerRules() {
        llvm::outs() << "** LaunchGuardPlugin: Registering rules...\n";

        // ---- 实例化并注册规则 ----
        registeredRules.push_back(std::make_unique<LoadMethodFileManagerRule>(CI));
        registeredRules.push_back(std::make_unique<MainThreadSyncSDKRule>(CI));
        // -------------------------

        llvm::outs() << "** LaunchGuardPlugin: Registered "
                     << registeredRules.size() << " rules.\n";
        if (registeredRules.empty()) {
             llvm::outs() << "** LaunchGuardPlugin: Warning - No rules registered!\n";
        }
    }
};

// ---- Plugin AST Action ----
// 插件的主要入口点，负责创建 AST Consumer
class LaunchGuardPluginAction : public clang::PluginASTAction {
public:
    std::unique_ptr<clang::ASTConsumer> CreateASTConsumer(clang::CompilerInstance &CI, llvm::StringRef InFile) override {
        llvm::outs() << "** LaunchGuardPlugin: Creating AST Consumer for file: " << InFile << "\n";
        return std::make_unique<LaunchGuardASTConsumer>(CI);
    }

    // 解析插件参数 (如果需要的话)
    bool ParseArgs(const clang::CompilerInstance &CI, const std::vector<std::string>& args) override {
        llvm::outs() << "** LaunchGuardPlugin: Parsing Args (if any)...\n";
        // 在这里可以处理传递给插件的参数，例如 -Xclang -plugin-arg-launchguardplugin -enable-rule=XYZ
        for (const std::string& arg : args) {
            llvm::errs() << "LaunchGuardPlugin Arg: " << arg << "\n";
        }
        return true; // 返回 true 表示参数解析成功
    }

    // 指定插件是应用于预处理结束还是语法分析结束
     PluginAction::ActionType getActionType() override {
       return PluginAction::AddAfterMainAction; // 在 Clang 主要操作后执行
     }
};

} // namespace launchguard

// ---- 插件注册 ----
// 使用 Clang 的 FrontendPluginRegistry 将我们的插件注册进去
static clang::FrontendPluginRegistry::Add<launchguard::LaunchGuardPluginAction>
X("LaunchGuardPlugin", "Checks for potential launch time performance issues."); // "插件名称", "插件描述" 