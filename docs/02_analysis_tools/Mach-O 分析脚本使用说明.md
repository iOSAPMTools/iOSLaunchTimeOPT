# Mach-O 分析脚本使用说明

## 1. 概述

`analyze_macho_load_methods.py` 是一个 Python 脚本，用于分析 iOS 应用的 Mach-O 可执行文件，旨在帮助识别可能包含 Objective-C `+load` 方法的类。这些类是启动性能优化的一个重要关注点，因为它们的 `+load` 方法会在类加载时同步执行，增加 pre-main 阶段的耗时。

**注意**: 当前版本的脚本主要通过列出 Mach-O 文件中所有的 Objective-C 类来提供一个排查范围。精确识别哪些类真正实现了 `+load` 方法并位于 non-lazy class list 中，需要更复杂的分析，当前脚本暂未完全实现。

## 2. 依赖

*   **Python 3**: 脚本需要 Python 3 环境。
*   **LIEF 库**: 需要安装 LIEF 库来解析 Mach-O 文件。

## 3. 安装依赖

使用 pip 安装 LIEF 库：
```bash
pip install lief
```
或者
```bash
pip3 install lief
```
请确保你的 pip 指向正确的 Python 3 版本。

## 4. 使用方法

脚本通过命令行运行，需要一个参数：指向你的 iOS 应用可执行文件的路径。

**定位可执行文件**:
通常，这个文件位于你的应用 `.app` 包内，与 `.app` 包同名且没有扩展名。例如，如果你的应用是 `MyApp.app`，可执行文件通常是 `MyApp.app/MyApp`。

**运行命令**:
```bash
python analyze_macho_load_methods.py /path/to/your/app/YourApp.app/YourApp
```
或者，如果脚本有执行权限：
```bash
./analyze_macho_load_methods.py /path/to/your/app/YourApp.app/YourApp
```

## 5. 输出说明

脚本会输出一个列表，包含在 Mach-O 文件中找到的所有 Objective-C 类的名称。

**示例输出**: 