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
                "src",
                "include",
                "doc", "examples", "hands", "test",
                "Sources", "Tests",
                "ChangeLog", "LICENSE", "README.md",
                "library/VENDOR-REF.txt"
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
            path: "Sources/DDSSwift",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "DDSSwiftTests",
            dependencies: ["DDSSwift"],
            path: "Tests/DDSSwiftTests",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        )
    ],
    cxxLanguageStandard: .cxx20
)
