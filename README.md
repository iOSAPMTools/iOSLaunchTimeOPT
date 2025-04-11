# iOS 启动优化系统

本项目旨在构建一套系统化的 iOS 应用启动性能优化解决方案，涵盖从测量、分析、优化到监控的全流程，以持续提升用户体验。

## 核心理念

应用启动速度是用户体验的关键一环。过长的启动时间可能导致用户流失。本项目摒弃零散的优化手段，倡导建立一套可持续迭代的优化体系，遵循 **测量 -> 分析 -> 优化 -> 监控** 的闭环思路，确保优化效果可衡量、问题可定位、成果可持续、性能不退化。

## 系统构成

本优化系统主要包含以下四个核心部分：

1.  **基础测量体系 (`docs/01_measurement`)**: 建立稳定、准确的启动耗时测量能力，为性能分析和优化效果评估提供数据基础。
2.  **深度分析工具集 (`docs/02_analysis_tools`)**: 开发和集成多种工具，用于深入定位启动过程中的性能瓶颈。
3.  **优化实践与自动化 (`docs/03_optimization`)**: 实施业界成熟的优化方案，并尽可能自动化，降低维护成本。
4.  **监控与防劣化机制 (`docs/04_monitoring_guidelines`)**: 建立持续监控和 CI/CD 集成，防止已优化的性能指标再次劣化。

## 主要功能与工具

### 1. 测量体系

*   **测量指标与方法**: 定义了标准的启动阶段（如 pre-main, main）和测量方法，结合系统能力 (`MetricKit`, `os_signpost`) 与自定义打点，确保数据的准确性和全面性。
    *   详见: [`docs/01_measurement/启动时间测量规范.md`](docs/01_measurement/启动时间测量规范.md)
*   **APM 集成**: 提供了数据上报的工具代码和与 APM 系统集成的说明，方便将启动耗时数据纳入统一监控平台。
    *   详见: [`docs/01_measurement/APM 集成说明-启动时间篇.md`](docs/01_measurement/APM%20%E9%9B%86%E6%88%90%E8%AF%B4%E6%98%8E-%E5%90%AF%E5%8A%A8%E6%97%B6%E9%97%B4%E7%AF%87.md)

### 2. 分析工具集

*   **Mach-O 分析 (`+load` 方法扫描)**:
    *   提供 Python 脚本 (`scripts/analyze_macho_load_methods.py`) 用于静态分析 Mach-O 文件，快速定位项目中实现的 Objective-C `+load` 方法，这些方法是 pre-main 阶段耗时的常见原因之一。
    *   脚本: [`scripts/analyze_macho_load_methods.py`](scripts/analyze_macho_load_methods.py)
    *   使用说明: [`docs/02_analysis_tools/Mach-O 分析脚本使用说明.md`](docs/02_analysis_tools/Mach-O%20%E5%88%86%E6%9E%90%E8%84%9A%E6%9C%AC%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E.md)
*   **Clang 插件 (静态代码扫描)**:
    *   开发了一套基于 Clang 的插件 (`LaunchGuardPlugin`)，用于在编译期静态扫描代码，识别潜在的启动性能问题。
    *   已实现的检查规则示例：
        *   检测 `+load` 方法中不推荐的文件读写操作。
        *   检测在主线程同步初始化第三方 SDK (如 Bugly) 的行为。
    *   插件说明: [`docs/02_analysis_tools/clang_plugin/Clang_启动性能扫描插件说明.md`](docs/02_analysis_tools/clang_plugin/Clang_%E5%90%AF%E5%8A%A8%E6%80%A7%E8%83%BD%E6%89%AB%E6%8F%8F%E6%8F%92%E4%BB%B6%E8%AF%B4%E6%98%8E.md)
    *   *注：Clang 插件源码位于 `src/clang_plugin/` (未在此仓库提供，但计划中有提及)*
*   **Swift 分析研究**:
    *   对 Swift Runtime 机制、Mach-O 中的 Swift 元数据进行了研究。
    *   探讨了利用 `SwiftSyntax` 或 `SwiftLint` 自定义规则进行 Swift 代码静态分析以发现启动性能问题的可行性，并进行了原型对比。
    *   研究文档: [`docs/02_analysis_tools/swift/`](docs/02_analysis_tools/swift/)

### 3. 优化实践与自动化

*   **二进制重排 (Binary Reordering)**:
    *   通过优化启动阶段所需函数和数据的排列顺序，减少 Page Fault，提升 IO 效率。
    *   提供了基于 Clang 插桩数据生成 Order File 的 Python 脚本 (`scripts/generate_order_file.py`)。
    *   脚本: [`scripts/generate_order_file.py`](scripts/generate_order_file.py)
    *   实施指南: [`docs/03_optimization/二进制重排实施指南.md`](docs/03_optimization/%E4%BA%8C%E8%BF%9B%E5%88%B6%E9%87%8D%E6%8E%92%E5%AE%9E%E6%96%BD%E6%8C%87%E5%8D%97.md)
    *   研究文档: [`docs/03_optimization/二进制重排研究与实践.md`](docs/03_optimization/%E4%BA%8C%E8%BF%9B%E5%88%B6%E9%87%8D%E6%8E%92%E7%A0%94%E7%A9%B6%E4%B8%8E%E5%AE%9E%E8%B7%B5.md)
*   **`+load` 方法治理**:
    *   梳理和改造项目中非必要的 `+load` 方法实现，将其逻辑延迟到更合适的时机执行（如 `+initialize` 或首次使用时）。
    *   治理文档: [`docs/03_optimization/+load 方法治理文档.md`](docs/03_optimization/+load%20%E6%96%B9%E6%B3%95%E6%B2%BB%E7%90%86%E6%96%87%E6%A1%A3.md)

### 4. 监控与防劣化机制

*   **CI/CD 集成**:
    *   提供了将启动时间测量集成到 CI/CD 流水线的说明，实现自动化测试。
    *   支持设置性能基线和阈值，在流水线中及时发现性能退化并告警。
    *   集成说明: [`docs/04_monitoring_guidelines/CI CD 集成启动时间监控说明.md`](docs/04_monitoring_guidelines/CI%20CD%20%E9%9B%86%E6%88%90%E5%90%AF%E5%8A%A8%E6%97%B6%E9%97%B4%E7%9B%91%E6%8E%A7%E8%AF%B4%E6%98%8E.md)
*   **APM 监控看板**:
    *   设计了在 APM 系统中展示启动性能数据的看板，方便长期趋势监控和版本对比。
    *   看板设计: [`docs/04_monitoring_guidelines/启动性能监控看板设计.md`](docs/04_monitoring_guidelines/%E5%90%AF%E5%8A%A8%E6%80%A7%E8%83%BD%E7%9B%91%E6%8E%A7%E7%9C%8B%E6%9D%BF%E8%AE%BE%E8%AE%A1.md)
*   **开发规范**:
    *   沉淀总结了启动性能相关的开发规范，旨在从源头减少性能问题的引入。
    *   规范文档: [`docs/04_monitoring_guidelines/开发规范-启动性能篇.md`](docs/04_monitoring_guidelines/%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83-%E5%90%AF%E5%8A%A8%E6%80%A7%E8%83%BD%E7%AF%87.md)

## 如何使用/参与

*   **学习**: 阅读 `docs` 目录下的文档，了解 iOS 启动优化的原理、测量方法、分析手段和优化技术。
*   **使用**:
    *   运行 `scripts/` 下的脚本来分析你的项目。
    *   参考文档和规范，应用到你的开发实践中。
    *   借鉴 Clang 插件的设计思路或规则，构建自己的静态检查能力。
*   **贡献**:
    *   提出 Issue 或 Pull Request 来改进文档或脚本。
    *   分享你的启动优化实践经验。