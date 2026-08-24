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
                "doc", "examples", "hands", "test",
                "Sources", "Tests",
                "ChangeLog", "LICENSE", "README.md",
                "library/VENDOR-REF.txt",
                // Non-source files — not processed by SPM
                "library/src/module.modulemap",
                "library/src/BUILD.bazel",
                "library/src/README_SolverContext.md",
                "library/src/api/BUILD.bazel",
                "library/src/heuristic_sorting/BUILD.bazel",
                "library/src/lookup_tables/BUILD.bazel",
                "library/src/moves/BUILD.bazel",
                "library/src/solver_context/BUILD.bazel",
                "library/src/system/BUILD.bazel",
                "library/src/trans_table/BUILD.bazel",
                "library/src/utility/BUILD.bazel"
            ],
            sources: ["library/src"],
            publicHeadersPath: "library/src",
            cxxSettings: [
                .headerSearchPath("library/src")
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
    ],
    cxxLanguageStandard: .cxx20
)
