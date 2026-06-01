// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypeShield",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TypeShield", targets: ["TypeShield"]),
    ],
    targets: [
        .executableTarget(
            name: "TypeShield",
            path: "Sources"
        )
    ]
)
