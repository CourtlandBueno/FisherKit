// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
#if os(Linux)
let package = Package(
    name: "FisherKit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FisherKit",
            targets: ["FisherKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FisherKit",
            dependencies: ["ShellOut"]),
        .testTarget(
            name: "FisherKitTests",
            dependencies: ["FisherKit"]),
    ]
)
#else

let package = Package(
    name: "FisherKit",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FisherKit",
            targets: ["FisherKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FisherKit",
            dependencies: []),
        .testTarget(
            name: "FisherKitTests",
            dependencies: ["FisherKit"]),
    ]
)
#endif
