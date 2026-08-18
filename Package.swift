// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuoteBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuoteBarCore", targets: ["QuoteBarCore"]),
        .executable(name: "QuoteBar", targets: ["QuoteBar"]),
    ],
    targets: [
        .target(
            name: "QuoteBarCore",
            path: "Sources/QuoteBarCore"
        ),
        .executableTarget(
            name: "QuoteBar",
            dependencies: ["QuoteBarCore"],
            path: "Sources/QuoteBar"
        ),
        .testTarget(
            name: "QuoteBarCoreTests",
            dependencies: ["QuoteBarCore"],
            path: "Tests/QuoteBarCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
