// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UnfoldMyMac",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "UnfoldMyMac", targets: ["UnfoldMyMac"]),
    ],
    targets: [
        .target(name: "UnfoldMyMacCore"),
        .target(name: "UnfoldMyMacKit", dependencies: ["UnfoldMyMacCore"], resources: [.copy("Shaders"), .copy("Resources")]),
        .executableTarget(name: "UnfoldMyMac", dependencies: ["UnfoldMyMacKit"]),
        .testTarget(name: "UnfoldMyMacCoreTests", dependencies: ["UnfoldMyMacCore"]),
        .testTarget(name: "UnfoldMyMacKitTests", dependencies: ["UnfoldMyMacKit", "UnfoldMyMacCore"]),
    ]
)
