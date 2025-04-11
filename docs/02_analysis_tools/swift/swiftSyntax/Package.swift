// Package.swift
// swift-tools-version:5.7 // 使用你兼容的 Swift 版本
import PackageDescription

let package = Package(
    name: "LaunchGuardSyntaxTool",
    platforms: [.macOS(.v12)], // 需要较新的 macOS 来运行
    dependencies: [
        // 依赖 SwiftSyntax 库
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"), // 使用兼容的版本号
    ],
    targets: [
        .executableTarget(
            name: "LaunchGuardSyntaxTool",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
            ]),
    ]
)