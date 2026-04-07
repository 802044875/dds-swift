// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dds-swift",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "DDSSwift", targets: ["DDSSwift"])
    ],
    targets: [
        .target(
            name: "DDS",
            path: ".",
            exclude: [
                "src/COMMENT", "src/Exports.def", "src/Makefile_Win_clang_static",
                "src/Makefiles", "src/dds.rc",
                "doc", "examples", "hands", "test",
                "Sources", "Tests",
                "ChangeLog", "LICENSE", "README.md"
            ],
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src"),
                .define("DDS_THREADS_GCD", .when(platforms: [.iOS, .macOS]))
            ]
        ),
        .target(
            name: "DDSSwift",
            dependencies: ["DDS"],
            path: "Sources/DDSSwift"
        ),
        .testTarget(
            name: "DDSSwiftTests",
            dependencies: ["DDSSwift"],
            path: "Tests/DDSSwiftTests"
        )
    ]
)
