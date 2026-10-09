// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusCore",
    platforms: [.macOS(.v13)],
    products: [
        // Static: the daemon is a bare executable and cannot embed a dynamic framework.
        .library(name: "FocusCore", type: .static, targets: ["FocusCore"]),
    ],
    targets: [
        .target(name: "FocusCore"),
        .testTarget(name: "FocusCoreTests", dependencies: ["FocusCore"]),
    ]
)
