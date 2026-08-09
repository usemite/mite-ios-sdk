// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mite",
    // macOS is declared so `swift test` runs on a Mac host.
    // iOS is the only supported deployment target.
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Mite", targets: ["Mite"])
    ],
    targets: [
        .target(name: "Mite"),
        .testTarget(name: "MiteTests", dependencies: ["Mite"]),
    ]
)
