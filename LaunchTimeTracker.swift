import Foundation
import os.log

// 定义时间点枚举，方便管理
enum LaunchTimePoint: String {
    case mainStart // T2
    case didFinishLaunchingStart // T3
    case didFinishLaunchingEnd // T4
    case firstFrameDidAppear // T5
}

// 用于记录和管理启动时间戳的单例类
final class LaunchTimeTracker {
    static let shared = LaunchTimeTracker()

    // 使用 os_log 记录 Points of Interest
    private let poiLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.unknown", category: .pointsOfInterest)
    // 为每次启动生成唯一的 Signpost ID，以便关联事件
    private let launchSignpostID: OSSignpostID

    // 存储各个时间点的时间戳 (使用 CACurrentMediaTime)
    private var timePoints: [LaunchTimePoint: CFTimeInterval] = [:]
    private let queue = DispatchQueue(label: "com.yourcompany.launchtracker.queue") // 保证线程安全

    private init() {
        // 在初始化时生成唯一的 Signpost ID
        launchSignpostID = OSSignpostID(log: poiLog)
        // 可以在这里标记整个启动流程的开始，如果需要的话
        // os_signpost(.begin, log: poiLog, name: "AppLaunch", signpostID: launchSignpostID)
        // 但更常见的做法是在 main 或 didFinishLaunchingWithOptions 开始时标记
    }

    /// 获取本次启动的 Signpost ID
    func getLaunchSignpostID() -> OSSignpostID {
        return launchSignpostID
    }

    /// 记录指定时间点的时间戳
    /// - Parameters:
    ///   - point: 时间点枚举值
    ///   - time: 使用 CACurrentMediaTime() 获取的时间戳
    func recordTime(point: LaunchTimePoint, time: CFTimeInterval = CACurrentMediaTime()) {
        queue.async { // 异步写入，避免阻塞主线程，尽管记录本身很快
            self.timePoints[point] = time
            // NSLog("[LaunchTime] Recorded \(point.rawValue): \(time)") // Debug 输出
        }

        // 根据时间点触发 os_signpost 事件
        switch point {
        case .mainStart:
             // 如果需要在 main 开始标记，可以在这里添加 .begin
             os_signpost(.event, log: poiLog, name: "Main Function Start", signpostID: launchSignpostID)
        case .didFinishLaunchingStart:
            os_signpost(.begin, log: poiLog, name: "didFinishLaunchingWithOptions", signpostID: launchSignpostID)
        case .didFinishLaunchingEnd:
            os_signpost(.end, log: poiLog, name: "didFinishLaunchingWithOptions", signpostID: launchSignpostID)
        case .firstFrameDidAppear:
            // 标记首帧出现，也可能意味着关键启动流程结束
             os_signpost(.end, log: poiLog, name: "AppLaunchToFirstFrame", signpostID: launchSignpostID)
             // 在这里可以触发计算和上报逻辑 (将在任务 3 实现)
             calculateAndPrepareReport()
        }
    }

    /// 获取指定时间点的时间戳
    func getTime(point: LaunchTimePoint) -> CFTimeInterval? {
        // 同步读取，确保获取到最新值（虽然是值类型拷贝，但 queue.sync 保证了写入已完成）
        return queue.sync {
            self.timePoints[point]
        }
    }

    /// 计算各阶段耗时并触发上报
    private func calculateAndPrepareReport() {
         queue.async { // 计算和准备数据异步进行
            guard let t2 = self.timePoints[.mainStart],
                  let t3 = self.timePoints[.didFinishLaunchingStart],
                  let t4 = self.timePoints[.didFinishLaunchingEnd],
                  let t5 = self.timePoints[.firstFrameDidAppear] else {
                os_log(.error, log: self.poiLog, "缺少必要的启动时间点，无法计算和上报。")
                return
            }

            let mainPrepareMs = (t3 - t2) * 1000
            let didFinishLaunchMs = (t4 - t3) * 1000
            let firstFramePrepareMs = (t5 - t4) * 1000
            let totalMainMs = (t5 - t2) * 1000 // 应用层总耗时

            os_log(.info, log: self.poiLog, "启动耗时计算完成 (ms) - MainPrepare: %.2f, DidFinishLaunch: %.2f, FirstFramePrepare: %.2f, TotalMain: %.2f", mainPrepareMs, didFinishLaunchMs, firstFramePrepareMs, totalMainMs)

            // 准备上报数据
            let reportData = LaunchTimeReportData(
                mainPrepareMs: mainPrepareMs,
                didFinishLaunchMs: didFinishLaunchMs,
                firstFramePrepareMs: firstFramePrepareMs,
                totalMainMs: totalMainMs,
                appVersion: LaunchTimeReporter.getAppVersion(),
                buildVersion: LaunchTimeReporter.getBuildVersion(),
                osVersion: LaunchTimeReporter.getOSVersion(),
                deviceModel: LaunchTimeReporter.getDeviceModel()
            )

            // 调用 Reporter 进行上报
            LaunchTimeReporter.shared.report(data: reportData)
        }
    }
} 