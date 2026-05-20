// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeepSeekMenuBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "DeepSeekMenuBar",
            path: "Sources/DeepSeekMenuBar",
            resources: [.process("Resources")]
        )
    ]
)
