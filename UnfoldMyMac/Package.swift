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
        .target(name: "UnfoldMyMacKit", dependencies: ["UnfoldMyMacCore", "UnfoldMyMacWallpaperBridge"], resources: [.copy("Shaders"), .copy("Resources")]),
        .executableTarget(name: "UnfoldMyMac", dependencies: ["UnfoldMyMacKit"]),
        // Reconstructed private wallpaper-extension contract. Header-only ObjC target so the
        // Swift extension can see the NSXPC protocols without a bridging header.
        .target(name: "UnfoldMyMacWallpaperBridge"),
        // The macOS 26 wallpaper provider. Packaged as a .appex inside the app by
        // script/build_and_run.sh; ExtensionKit requires _NSExtensionMain as the Mach-O
        // entry point, and without it the process exits before serving a single XPC call.
        .executableTarget(
            name: "UnfoldMyMacWallpaperExtension",
            dependencies: ["UnfoldMyMacKit"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])]
        ),
        .testTarget(name: "UnfoldMyMacCoreTests", dependencies: ["UnfoldMyMacCore"]),
        .testTarget(name: "UnfoldMyMacKitTests", dependencies: ["UnfoldMyMacKit", "UnfoldMyMacCore"]),
    ]
)
