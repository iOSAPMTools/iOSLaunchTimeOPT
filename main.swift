import UIKit

// 记录 T2: Main 函数入口时间
// 注意：需要在 UIApplicationMain 之前记录
let mainStartTime = CACurrentMediaTime()
LaunchTimeTracker.shared.recordTime(point: .mainStart, time: mainStartTime)

// 如果你的 AppDelegate 类名不是 "AppDelegate"，需要在这里指定
let appDelegateClassName = NSStringFromClass(AppDelegate.self)

// 启动应用主循环
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, appDelegateClassName) 