// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RetroFilesystemGUI",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "RetroFilesystemGUI",
            path: "Sources/RetroFilesystemGUI"
        ),
        .testTarget(
            name: "RetroFilesystemGUITests",
            dependencies: ["RetroFilesystemGUI"],
            path: "Tests/RetroFilesystemGUITests"
        )
    ]
)
