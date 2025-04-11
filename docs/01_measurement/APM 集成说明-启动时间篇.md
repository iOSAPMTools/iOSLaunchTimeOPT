# APM 集成说明 - 启动时间篇 V1.1

**版本**: 1.1
**日期**: [请替换为当前日期]
**负责人**: [你的名字/AI]

## 1. 概述

本文档描述如何将 iOS 应用内采集的启动时间数据集成到现有的 APM (Application Performance Monitoring) 系统中。当前版本定义了上报的数据结构和基础的上报流程。

## 2. 数据来源

启动时间数据由应用内的 `LaunchTimeTracker` 模块采集，并在首帧渲染完成（T5 时间点）后，通过 `LaunchTimeReporter` 模块进行处理和上报。

## 3. 上报数据结构

每次冷启动完成后，将上报以下数据：

*   **指标 (Metrics)**:
    *   `main_prepare_ms`: Main 函数准备耗时 (T3-T2)，Double 类型，单位毫秒。
    *   `did_finish_launch_ms`: `didFinishLaunchingWithOptions` 耗时 (T4-T3)，Double 类型，单位毫秒。
    *   `first_frame_prepare_ms`: 首帧渲染准备耗时 (T5-T4)，Double 类型，单位毫秒。
    *   `total_main_ms`: 应用层总启动耗时 (T5-T2)，Double 类型，单位毫秒。
*   **维度 (Dimensions)**:
    *   `app_version`: 应用版本号 (CFBundleShortVersionString)，String 类型。
    *   `build_version`: 构建版本号 (CFBundleVersion)，String 类型。
    *   `os_version`: 操作系统版本 (UIDevice.current.systemVersion)，String 类型。
    *   `device_model`: 设备型号标识符 (e.g., "iPhone13,2")，String 类型。
    *   *(后续可根据 APM 系统能力和分析需求添加更多维度，如网络状态、地域、用户标识等)*

数据以键值对形式（字典）组织，便于序列化为 JSON 或其他格式。

## 4. 上报机制

*   **触发时机**: 在 `LaunchTimeTracker` 计算完所有耗时指标后触发。
*   **执行模块**: `LaunchTimeReporter.shared.report(data:)` 方法。
*   **核心逻辑**:
    1.  将 `LaunchTimeReportData` 结构体转换为字典。
    2.  将字典序列化为 JSON `Data`。
    3.  调用私有方法 `sendToAPMServer(jsonData:)` 来执行实际的网络上报。
*   **`sendToAPMServer` 函数 (待实现)**:
    *   **目的**: 负责通过网络将序列化后的 JSON 数据发送到 APM 后端服务器。
    *   **当前状态 (V1.1)**: 该函数包含了一个 **占位符实现**，仅打印日志表明将要发送数据，并提供了一个基于 `URLSession` 的网络请求框架代码（已注释）。
    *   **需要配置**:
        *   **APM 服务器 URL**: 在 `LaunchTimeReporter.swift` 中修改 `apmServerURL` 变量为真实的接口地址。
        *   **HTTP 请求头**: 根据 APM 服务器要求，在 `URLRequest` 中设置正确的 `Content-Type` (通常是 `application/json`) 和任何必要的认证信息 (如 `Authorization` Token)。
        *   **错误处理与重试**: 需要根据项目需求实现完整的错误处理逻辑（网络错误、服务器错误）和可能的重试机制。

## 5. APM 后台配置 (待定)

在 APM 后台，需要配置相应的指标和维度，以便对上报的数据进行存储、聚合和可视化展示。具体配置方式取决于所使用的 APM 系统。**此配置需在 `sendToAPMServer` 函数实现并成功发送数据后进行。**

## 6. 版本修订

| 版本 | 日期       | 修订者     | 说明                                                         |
| ---- | ---------- | ---------- | ------------------------------------------------------------ |
| 1.0  | [旧日期]   | [你的名字/AI] | 初版创建，定义数据结构和初步上报机制。                       |
| 1.1  | [今天日期] | [你的名字/AI] | 添加 `sendToAPMServer` 占位符实现，明确后续需配置的 APM 细节。 | 