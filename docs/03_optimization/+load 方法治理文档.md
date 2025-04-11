# +load 方法治理跟踪文档 V1.0

**版本**: 1.0
**日期**: [请替换为当前日期]
**负责人**: [团队/个人名称]

## 1. 概述

本文档用于系统性地梳理、分析和跟踪项目中 Objective-C `+load` 方法的治理情况。目标是识别并改造非必要的 `+load` 方法，将其逻辑迁移到更合适的时机（如 `+initialize` 或懒加载），以减少应用 Pre-main 阶段的启动耗时。

## 2. 分析与治理流程

1.  **识别**: 使用 Mach-O 分析工具（如 `scripts/analyze_macho_load_methods.py`）或静态分析工具，列出项目中所有包含 `+load` 方法的类。
2.  **分析**: 逐个分析每个 `+load` 方法：
    *   确定其**用途**（方法交换、注册、初始化等）。
    *   评估其**必要性**（是否必须在类加载时执行？）。
    *   判断其**影响**（移除或修改可能带来的风险）。
3.  **制定方案**: 根据分析结果，确定**建议操作**（保留、重构、移除）。
4.  **实施与验证**: 分配负责人，执行改造，并通过测试验证功能的正确性和启动性能的改善。
5.  **更新状态**: 在本文档中及时更新每个 `+load` 方法的处理状态。

## 3. +load 方法列表与治理状态

| 类名 (Class Name) | 所属库/模块 (Library/Module) | `+load` 用途分析 (Purpose Analysis) | 必要性评估 (Necessity Assessment) | 建议操作 (Suggested Action) | 负责人 (Owner) | 状态 (Status)             | 备注 (Notes) |
| :---------------- | :--------------------------- | :------------------------------------ | :---------------------------------- | :-------------------------- | :------------- | :------------------------ | :----------- |
| *(示例) UIViewController+Swizzling* | 主工程 / UIUtils | 对 `viewWillAppear:` 进行方法交换 | 高 (Swizzling 需尽早执行)          | Keep                        | 张三           | Done                      | 核心打点逻辑 |
| *(示例) MyCacheManager* | 主工程 / Cache   | 初始化全局缓存实例          | 低 (可在首次使用时初始化)            | Refactor (Lazy Load)        | 李四           | Developing                | 使用 `dispatch_once` 改造 |
| *(示例) ThirdPartySDKInitializer* | ThirdPartySDK.framework | 调用 SDK 的某个早期设置方法     | 中 (SDK 要求，但可能不严格)         | Analyze Further             | 王五           | Pending Analysis          | 需确认 SDK 文档和影响 |
| *[请在此处填充脚本扫描出的类列表]* |                      |                                       |                                     |                             |                | Pending Analysis          |              |
| ...               |                              |                                       |                                     |                             |                |                           |              |

**建议操作说明**:
*   `Keep`: 保留，不做修改。
*   `Refactor (+initialize)`: 改造为使用 `+initialize` 方法。
*   `Refactor (Lazy Load)`: 改造为其他懒加载方式 (如 `dispatch_once`, 首次访问时创建)。
*   `Refactor (Other)`: 其他改造方案。
*   `Remove`: 移除该 `+load` 方法。
*   `Analyze Further`: 需要进一步调研或讨论。

**状态说明**:
*   `Pending Analysis`: 待分析。
*   `Analyzed`: 已完成分析，建议操作已确定。
*   `Developing`: 正在进行代码改造。
*   `Pending Verification`: 代码改造完成，等待测试验证。
*   `Done`: 治理完成并通过验证。
*   `Wontfix`: 决定暂不处理。

## 4. 参考资料

*   [Effective Objective-C 2.0 - Item 52: Prefer dispatch_once for Thread-Safe Single-Time Code Execution](...)
*   [You Probably Don't Need +load](...)
*   [项目内部 `+initialize` vs `+load` 规范 (如有)] 