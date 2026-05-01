// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "wkwebview-element-fullscreen-repro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Repro",
            path: "Sources/Repro"
        )
    ]
)
