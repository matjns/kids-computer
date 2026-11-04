// swift-tools-version:5.9
import PackageDescription

// macOS 14 is required for the kiosk APIs. Linux CI and `swift test` only
// build the logic module; an empty platform list lets that succeed here.
#if os(macOS)
let packagePlatforms: [SupportedPlatform]? = [.macOS(.v14)]
#else
let packagePlatforms: [SupportedPlatform]? = nil
#endif

let package = Package(
    name: "KidsComputer",
    platforms: packagePlatforms,
    products: [
        .library(name: "KidsComputerCore", targets: ["KidsComputerCore"]),
        .executable(name: "KidsComputer", targets: ["KidsComputer"]),
    ],
    targets: [
        .target(name: "KidsComputerCore"),
        .executableTarget(
            name: "KidsComputer",
            dependencies: ["KidsComputerCore"],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("SwiftUI", .when(platforms: [.macOS])),
                .linkedFramework("ServiceManagement", .when(platforms: [.macOS])),
                .linkedFramework("Security", .when(platforms: [.macOS])),
                .linkedFramework("UniformTypeIdentifiers", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "KidsComputerCoreTests",
            dependencies: ["KidsComputerCore"]
        ),
    ]
)
