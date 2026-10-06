// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WiFiOrISPCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WiFiOrISPCore", targets: ["WiFiOrISPCore"])
    ],
    targets: [
        .target(name: "WiFiOrISPCore"),
        // Runs the probes and tests from a terminal, for development. Not shipped.
        .executableTarget(name: "wifiorisp-cli", dependencies: ["WiFiOrISPCore"]),
        .testTarget(name: "WiFiOrISPCoreTests", dependencies: ["WiFiOrISPCore"])
    ]
)
