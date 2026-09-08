// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UIFrameworkPolicy",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "UIFrameworkPolicy", targets: ["UIFrameworkPolicy"])
    ],
    targets: [
        .target(name: "UIFrameworkPolicy"),
        .testTarget(name: "UIFrameworkPolicyTests", dependencies: ["UIFrameworkPolicy"])
    ]
)
