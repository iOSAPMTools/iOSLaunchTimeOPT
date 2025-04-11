# Clang 插件开发环境搭建指南 (macOS 草稿)

## 1. 概述

本文档提供在 macOS 上搭建 Clang 插件开发环境的通用步骤指导。Clang 插件允许开发者在编译期间访问和分析代码的抽象语法树 (AST)，以实现自定义的代码检查、重构或其他静态分析任务。

**重要提示**:
*   Clang/LLVM 版本需要与你项目主要使用的 Xcode 版本中的 Clang **兼容或接近**。版本不匹配可能导致插件加载失败或行为异常。
*   编译 LLVM/Clang 是一个资源密集型过程，需要较长时间（可能数小时）和大量磁盘空间（数十 GB）。
*   以下步骤提供了多种方式，请根据你的具体情况选择。

## 2. 确定 Clang 版本

首先，确定你当前 Xcode 使用的 Clang 版本：
```bash
# 打开 Xcode 选择的命令行工具路径下的 clang
xcrun clang --version
```
记下输出中的版本号 (例如 `Apple clang version 14.0.3 (clang-1403.0.22.14.1)`)。你需要找到对应或接近的 LLVM 开源版本 (例如 LLVM 14.x, 15.x)。Apple Clang 版本与开源 LLVM 版本并非一一对应，但通常可以找到相近的 release 分支。

## 3. 获取 LLVM/Clang 源码

推荐从 LLVM 官方 GitHub 仓库克隆：
```bash
git clone https://github.com/llvm/llvm-project.git
cd llvm-project

# 检出与你 Xcode Clang 版本接近的 release 分支
# 例如，如果 Xcode 是 Clang 14.x，可以尝试 release/14.x 或 release/15.x
# 查看所有 release 分支: git branch -r | grep 'origin/release/'
git checkout release/15.x # <== 请替换为你选择的分支
```

## 4. 编译 LLVM/Clang (推荐方式)

这是最灵活的方式，可以确保你拥有完整的头文件和库文件。

**4.1 安装依赖**:
*   **CMake**: 构建系统。 `brew install cmake`
*   **Ninja**: (可选，但推荐) 更快的构建工具。 `brew install ninja`
*   **Xcode Command Line Tools**: 应已安装。 `xcode-select --install`

**4.2 配置构建 (使用 CMake)**:
在 `llvm-project` 目录外创建一个构建目录（避免污染源码）：
```bash
mkdir ../llvm-build
cd ../llvm-build

# 运行 CMake 配置
# 参数说明:
# -G Ninja: 使用 Ninja 作为构建工具 (如果安装了)
# -DCMAKE_BUILD_TYPE=Release: 构建 Release 版本 (性能更好)
# -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra': 需要构建的项目 (至少需要 clang)
# -DLLVM_TARGETS_TO_BUILD="X86;ARM;AArch64": 需要支持的目标架构 (根据你的需求调整，macOS 通常需要 X86 和 AArch64/ARM)
# -DLLVM_ENABLE_ASSERTIONS=ON: (可选) 开启断言，便于调试插件开发，但会降低性能
# -DCMAKE_INSTALL_PREFIX=../llvm-install: (可选) 指定安装目录
# ../llvm-project/llvm: 指向 llvm 源码目录

cmake -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra' \
      -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DCMAKE_INSTALL_PREFIX=../llvm-install \
      ../llvm-project/llvm
```

**4.3 执行编译**:
```bash
ninja # 或者如果没用 Ninja，则使用 make -j<CPU核心数>
```
这将花费很长时间。

**4.4 (可选) 安装**:
如果配置了 `CMAKE_INSTALL_PREFIX`，可以将编译好的文件安装到指定目录：
```bash
ninja install
```
安装目录 (`../llvm-install`) 将包含 `bin`, `lib`, `include` 等子目录。

## 5. 使用预编译版本或 Homebrew (备选方式)

**5.1 LLVM 官网预编译包**:
*   访问 https://releases.llvm.org/ 下载适用于 macOS 的预编译包 (`clang+llvm-*.tar.xz`)。
*   解压到你选择的目录。
*   **优点**: 节省编译时间。
*   **缺点**: 可能不包含所有开发所需的头文件或库文件，版本可能与 Xcode 不完全匹配。

**5.2 Homebrew**:
```bash
brew install llvm # 或 llvm@15 等特定版本
```
*   Homebrew 会将 LLVM 安装到特定路径 (例如 `/usr/local/opt/llvm` 或 `/opt/homebrew/opt/llvm`)。
*   **优点**: 管理方便。
*   **缺点**: 版本可能与 Xcode 不匹配，需要确保路径设置正确。

## 6. 环境配置

无论使用哪种方式，你可能需要配置环境变量，以便你的插件项目能找到 Clang/LLVM。

在你的 `~/.zshrc` 或 `~/.bash_profile` 中添加类似内容 (路径需要根据你的实际安装位置修改):

**如果你编译并安装到了 `../llvm-install`**:
```bash
export LLVM_DIR="/path/to/your/llvm-install" # 指向安装目录
export PATH="$LLVM_DIR/bin:$PATH"
```

**如果你使用的是 Homebrew**:
```bash
export LLVM_DIR="$(brew --prefix llvm)" # 获取 Homebrew 安装路径
export PATH="$LLVM_DIR/bin:$PATH"
# 可能还需要设置 LDFLAGS 和 CPPFLAGS 以便链接时找到库和头文件
export LDFLAGS="-L$LLVM_DIR/lib"
export CPPFLAGS="-I$LLVM_DIR/include"
```

**应用配置**:
```bash
source ~/.zshrc # 或 source ~/.bash_profile
```

**验证**:
打开新的终端，运行：
```bash
which clang # 应该指向你新安装或编译的 clang 路径
clang --version # 确认版本
```

## 7. 下一步

环境搭建完成后，你可以进行 **任务 6.3: 实现插件核心架构和规则基类**。这通常涉及：
*   创建一个新的 C++ 项目。
*   使用 CMake 来管理项目构建，并链接 Clang/LLVM 库 (例如 `clangAST`, `clangBasic`, `LLVMCore`, `LLVMSupport`)。
*   编写插件的入口代码、`PluginASTAction` 和 `ASTConsumer` 子类。

这个环境搭建过程可能遇到各种具体问题，需要根据错误信息查阅 LLVM 官方文档或社区寻求帮助。 