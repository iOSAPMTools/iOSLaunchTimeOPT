# Clang 启动性能扫描插件 (LaunchGuardPlugin) 说明 V1.0

**版本**: 1.0
**日期**: [请替换为当前日期]

## 1. 概述

LaunchGuardPlugin 是一个 Clang 插件，旨在通过静态分析 Objective-C/C++ 代码，在编译期间检测可能影响 iOS 应用启动性能的不良编码实践。它可以帮助开发者提前发现问题，遵守性能规范。

本插件基于可扩展架构设计，可以方便地添加新的检查规则。

## 2. 功能与当前规则

当前版本 (V1.0) 包含以下检查规则：

*   **`LoadMethodFileManagerRule`**:
    *   **检测**: 在 Objective-C `+load` 方法中直接调用 `NSFileManager` 的 `fileExistsAtPath:` 或 `createDirectoryAtPath:withIntermediateDirectories:attributes:error:` 方法。
    *   **Rationale**: `+load` 方法在类加载时同步执行，执行文件 I/O 操作会阻塞主线程，严重影响启动速度。
    *   **报告**: 在违规调用点报告编译时警告。
*   **`MainThreadSyncSDKRule`**:
    *   **检测**: 直接调用 `+[Bugly startWithAppId:]` 方法。
    *   **Rationale**: 一些 SDK 初始化方法可能包含同步的耗时操作（如网络、文件读写、复杂计算）。如果这些方法在主线程被调用，会阻塞 UI 响应，影响启动体验。此规则旨在提醒开发者关注特定 SDK 的调用位置。
    *   **注意**: 当前规则仅匹配方法调用，**不进行实际的线程检查**。开发者需要自行判断调用是否发生在主线程。
    *   **报告**: 在调用点报告编译时警告，提示进行检查。

## 3. 编译插件

**依赖**:
*   C++17 编译器
*   CMake (>= 3.13.4)
*   Ninja (推荐)
*   已配置好的 Clang/LLVM 开发环境 (头文件和库文件)，版本需与项目 Clang 兼容。请参考 `Clang_Plugin_Dev_Environment_Setup.md`。

**编译步骤**:
1.  确保你的 Clang/LLVM 开发环境已正确配置 (例如 `LLVM_DIR` 环境变量已设置)。
2.  进入插件源码目录 `src/clang_plugin/`。
3.  创建构建目录并进入: `mkdir build && cd build`
4.  运行 CMake 配置: `cmake .. -G Ninja` (或其他生成器)
5.  执行编译: `ninja` (或 `make`)
6.  编译成功后，插件库文件 (例如 `LaunchGuardPlugin.dylib`) 会出现在 `build` 目录下。

## 4. 集成到 Xcode 项目

1.  确定编译生成的 `LaunchGuardPlugin.dylib` 的**绝对路径**。
2.  在你的 Xcode 项目中，导航到 `Build Settings`。
3.  搜索 `Other C Flags` (或针对 C++/Objective-C 的类似设置)。
4.  在 Debug 配置下 (或所有需要检查的配置下)，添加以下标志，**将 `/path/to/your/LaunchGuardPlugin.dylib` 替换为实际路径**:
    ```
    -Xclang -load -Xclang /path/to/your/LaunchGuardPlugin.dylib -Xclang -plugin -Xclang LaunchGuardPlugin
    ```
5.  重新构建你的 Xcode 项目。插件将在编译过程中运行，相关的警告信息会显示在 Xcode 的 Build Log 或 Issue Navigator 中。

**注意**:
*   确保插件使用的 Clang/LLVM 版本与 Xcode 项目使用的 Clang 版本兼容。
*   插件路径错误或版本不兼容会导致编译失败或插件无法加载。

## 5. 如何添加新规则 (扩展指南)

本插件设计为易于扩展。要添加一个新的检查规则，请遵循以下步骤：

**步骤 1: 创建规则头文件 (`.h`)**
*   在 `src/clang_plugin/` 目录下创建一个新的头文件，例如 `MyNewRule.h`。
*   让你的新规则类继承自 `launchguard::DiagnosticRule`。
*   声明构造函数 `explicit MyNewRule(clang::CompilerInstance &CI);`。
*   重写 `getName()` 方法返回规则的唯一名称。
*   根据需要重写 `initialize()` 和 `finalize()`。
*   根据你的规则需要检查的 AST 节点类型，重写相应的 `visit*` 方法 (例如 `visitObjCMethodDecl`, `visitObjCMessageExpr`, `visitFunctionDecl`, `visitCallExpr`, `visitVarDecl` 等)。参考 `DiagnosticRule.h` 和 Clang 的 `RecursiveASTVisitor` 文档。

```cpp
// src/clang_plugin/MyNewRule.h (示例)
#ifndef LAUNCH_GUARD_PLUGIN_MY_NEW_RULE_H
#define LAUNCH_GUARD_PLUGIN_MY_NEW_RULE_H

#include "DiagnosticRule.h"

namespace launchguard {

class MyNewRule : public DiagnosticRule {
public:
    explicit MyNewRule(clang::CompilerInstance &CI);
    llvm::StringRef getName() const override;
    // 重写需要的 visit* 方法
    bool visitFunctionDecl(clang::FunctionDecl *D) override;
    // ...
};

} // namespace launchguard
#endif
```

**步骤 2: 创建规则实现文件 (`.cpp`)**
*   在 `src/clang_plugin/` 目录下创建对应的 `.cpp` 文件，例如 `MyNewRule.cpp`。
*   包含头文件 `#include "MyNewRule.h"` 和其他需要的 Clang 头文件。
*   实现构造函数、`getName()` 和你重写的 `visit*` 方法。
*   在 `visit*` 方法中编写你的检查逻辑。使用 `Context` (ASTContext) 获取 AST 信息，使用 `reportWarning()` 或 `reportError()` (继承自 `DiagnosticRule`) 报告诊断信息。

```cpp
// src/clang_plugin/MyNewRule.cpp (示例)
#include "MyNewRule.h"
#include "clang/AST/Decl.h" // For FunctionDecl

namespace launchguard {

MyNewRule::MyNewRule(clang::CompilerInstance &CI) : DiagnosticRule(CI) {}

llvm::StringRef MyNewRule::getName() const { return "MyNewRule"; }

bool MyNewRule::visitFunctionDecl(clang::FunctionDecl *D) {
    if (D && D->getNameInfo().getAsString() == "someProblematicFunction") {
        reportWarning(D->getLocation(), "调用了不推荐的函数 someProblematicFunction");
    }
    return true; // 继续访问子节点
}

// ... 其他实现 ...
} // namespace launchguard
```

**步骤 3: 注册新规则**
*   打开 `src/clang_plugin/LaunchGuardPlugin.cpp` 文件。
*   在文件顶部 `#include` 新规则的头文件 (`#include "MyNewRule.h"`).
*   找到 `LaunchGuardASTConsumer::registerRules()` 方法。
*   在该方法中，添加一行代码来实例化并注册你的新规则：
    ```cpp
    registeredRules.push_back(std::make_unique<MyNewRule>(CI));
    ```

**步骤 4: 重新编译插件**
*   回到 `src/clang_plugin/build` 目录。
*   运行 `ninja` 或 `make` 重新编译插件。
*   新的规则现在应该已经包含在插件中了。

## 6. 示例用法与输出

编译包含以下代码的文件时：
```objc
// example.m
#import <Foundation/Foundation.h>

// Mock Bugly for testing
@interface Bugly : NSObject
+ (void)startWithAppId:(NSString *)appId;
@end
@implementation Bugly
+ (void)startWithAppId:(NSString *)appId { NSLog(@"Mock Bugly called"); }
@end

@interface Example : NSObject {}
+ (void)load;
- (void)doSomething;
@end

@implementation Example
+ (void)load {
    // 应该触发警告
    [[NSFileManager defaultManager] fileExistsAtPath:@"/"];
    NSLog(@"Example +load called");
}
- (void)doSomething {
    // 应该触发警告 (假设在主线程)
    [Bugly startWithAppId:@"test_id"];
}
@end
```
使用插件编译 (`clang -c example.m -fmodules -fobjc-arc -Xclang -load -Xclang /path/to/LaunchGuardPlugin.dylib -Xclang -plugin -Xclang LaunchGuardPlugin`)，预期会看到类似警告：
