// LaunchPerformanceTests.swift
// 将此文件添加到你的项目的一个 UI Test Target 或 Unit Test Target 中。
// UI Test Target 更能模拟真实用户启动场景。

import XCTest

final class LaunchPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        // 测试开始前不启动 App，确保 measureMetrics 测量的是冷启动
        continueAfterFailure = false
    }

    func testColdLaunchPerformance() throws {
        // 检查是否在支持启动测量的系统版本上运行 (iOS 13+)
        if #available(iOS 13.0, *) {
            // 创建要测量的 App 实例 (对于 UI 测试)
            let app = XCUIApplication()

            // 使用 measure(metrics:block:) 和 XCTApplicationLaunchMetric
            // 它会自动处理多次运行和计算基线
            self.measure(metrics: [XCTApplicationLaunchMetric()]) {
                // block 内部执行启动 App 的操作
                // 对于 UI 测试，通常是调用 app.launch()
                // XCTest 会自动终止并重新启动 App 来进行多次测量
                app.launch()

                // (可选) 在启动后可以添加一些简单的断言，确保 App 启动成功
                // 例如，检查某个启动后应该存在的元素
                 XCTAssertTrue(app.staticTexts["WelcomeLabel"].waitForExistence(timeout: 10), "App 首页未能正常加载")
            }
        } else {
            // 对于旧版本系统，可以跳过此测试或使用其他测量方法
            print("[LaunchPerformanceTests] 跳过启动性能测试，因为系统版本低于 iOS 13.0")
            throw XCTSkip("启动性能测试需要 iOS 13.0 或更高版本")
        }
    }

    // 可以添加更多测试用例来测量其他场景，例如热启动，
    // 但 XCTApplicationLaunchMetric 主要设计用于冷启动。
}