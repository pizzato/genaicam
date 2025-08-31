// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MLXLibraries",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "MLXLMCommon", targets: ["MLXLMCommon"]),
        .library(name: "MLXVLM", targets: ["MLXVLM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", .exact("0.25.6")),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .exact("0.1.22")),
    ],
    targets: [
        .target(
            name: "MLXLMCommon",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "MLXLMCommon",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "MLXVLM",
            dependencies: [
                "MLXLMCommon",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "MLXVLM",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
