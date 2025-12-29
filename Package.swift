// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "hokusai-vapor",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "HokusaiVapor",
            targets: ["HokusaiVapor"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"),
        // Hokusai core library
        .package(url: "https://github.com/ivantokar/hokusai.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "HokusaiVapor",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Hokusai", package: "hokusai"),
            ]
        ),
        .testTarget(
            name: "HokusaiVaporTests",
            dependencies: [
                "HokusaiVapor",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
