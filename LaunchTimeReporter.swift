import Foundation
import UIKit // 用于获取设备信息等
import os.log // 引入 os.log

// 定义上报的数据结构
struct LaunchTimeReportData {
    // 各阶段耗时 (单位: ms)
    let mainPrepareMs: Double
    let didFinishLaunchMs: Double
    let firstFramePrepareMs: Double
    let totalMainMs: Double // T5-T2

    // 维度信息 (示例)
    let appVersion: String
    let buildVersion: String
    let osVersion: String
    let deviceModel: String
    // 可以添加更多维度，如网络状态、是否越狱、用户 ID 等

    // 将数据转换为字典，方便后续 JSON 序列化或直接上报
    func asDictionary() -> [String: Any] {
        return [
            "main_prepare_ms": mainPrepareMs,
            "did_finish_launch_ms": didFinishLaunchMs,
            "first_frame_prepare_ms": firstFramePrepareMs,
            "total_main_ms": totalMainMs,
            "app_version": appVersion,
            "build_version": buildVersion,
            "os_version": osVersion,
            "device_model": deviceModel
        ]
    }
}

// 负责启动时间数据上报的单例类
final class LaunchTimeReporter {
    static let shared = LaunchTimeReporter()

    private let reportQueue = DispatchQueue(label: "com.yourcompany.launchreporter.queue", qos: .background)
    // APM 服务器的上报地址 (占位符，需要替换为真实 URL)
    private let apmServerURL: URL? = URL(string: "https://your-apm-server.com/api/launch_metrics")

    private init() {} // 私有化构造函数

    /// 上报启动时间数据
    /// - Parameter data: 包含耗时和维度信息的结构体
    func report(data: LaunchTimeReportData) {
        reportQueue.async {
            let reportDict = data.asDictionary()

            // 将字典转换为 JSON Data
            guard let jsonData = try? JSONSerialization.data(withJSONObject: reportDict, options: []) else {
                os_log(.error, log: OSLog.default, "无法将启动数据序列化为 JSON")
                return
            }

            // 调用实际的发送函数
            self.sendToAPMServer(jsonData: jsonData)
        }
    }

    // --- 实际发送数据的函数 (待实现) ---
    private func sendToAPMServer(jsonData: Data) {
        guard let url = apmServerURL else {
            os_log(.error, log: OSLog.default, "APM 服务器 URL 未配置")
            // 也可以在这里考虑本地缓存失败的上报数据，稍后重试
            return
        }

        // --- 在这里实现网络请求逻辑 ---
        // 1. 创建 URLRequest (POST)
        // 2. 设置 Header (e.g., Content-Type: application/json, Authorization tokens)
        // 3. 设置 HTTPBody 为 jsonData
        // 4. 使用 URLSession 发送请求
        // 5. 处理响应 (成功或失败，日志记录，错误处理，重试机制等)

        // 占位符: 打印表示将要发送
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "Invalid JSON Data"
        print("[LaunchTimeReporter] 准备发送到 \(url.absoluteString): \(jsonString)")
        os_log(.debug, log: OSLog.default, "准备发送启动数据到 APM 服务器: %{public}@", url.absoluteString)

        // --- 示例 URLSession 实现框架 (需要取消注释并完善) ---
        /*
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // request.setValue("Bearer YOUR_AUTH_TOKEN", forHTTPHeaderField: "Authorization") // 添加认证信息

        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                os_log(.error, log: OSLog.default, "发送启动数据到 APM 失败: %{public}@", error.localizedDescription)
                // 处理错误，例如重试
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                os_log(.error, log: OSLog.default, "无效的 APM 服务器响应")
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                os_log(.info, log: OSLog.default, "启动数据成功发送到 APM 服务器")
            } else {
                os_log(.error, log: OSLog.default, "APM 服务器返回错误状态码: %d", httpResponse.statusCode)
                // 处理服务器错误
            }
        }
        task.resume()
        */
        // --- URLSession 实现结束 ---
    }

    // --- Helper 方法获取维度信息 ---
    static func getAppVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }

    static func getBuildVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    static func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier // e.g., "iPhone13,2"
    }
} 