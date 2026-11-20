// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SierraPortApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SierraPortApp", targets: ["SierraPortApp"])
    ],
    targets: [
        .executableTarget(
            name: "SierraPortApp",
            path: "Sources/SierraPortApp",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
