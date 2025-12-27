// swift-tools-version: 5.9
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
        .package(path: "../hokusai"),
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
            dependencies: ["HokusaiVapor"]
        ),
    ]
)
