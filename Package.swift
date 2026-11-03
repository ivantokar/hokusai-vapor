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
        .package(url: "https://github.com/ivantokar/hokusai.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "HokusaiVapor",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Hokusai", package: "hokusai"),
                .product(name: "HokusaiNIO", package: "hokusai"),
            ]
        ),
        .testTarget(
            name: "HokusaiVaporTests",
            dependencies: [
                "HokusaiVapor",
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
    ]
)
