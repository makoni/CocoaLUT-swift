// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CocoaLUTSwift",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CocoaLUTSwift",
            type: .dynamic,
            targets: ["CocoaLUTSwift"],
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CocoaLUTSwift",
            resources: [
                // .copy preserves the on-disk hierarchy so subdirectory: lookups
                // via Bundle.module.url(...) match the file tree.
                .copy("TransferFunctionLUTs")
            ]
        ),
        .testTarget(
            name: "CocoaLUTSwiftTests",
            dependencies: ["CocoaLUTSwift"],
            resources: [
                .process("Resources"),
                .copy("TestLUTs")
            ]
        ),
    ]
)
