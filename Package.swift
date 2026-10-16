// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Trazo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Trazo", targets: ["Trazo"])],
    targets: [
        .target(name: "CaptureCore", linkerSettings: [.linkedFramework("AppKit")]),
        .executableTarget(
            name: "Trazo",
            dependencies: ["CaptureCore"],
            linkerSettings: [.linkedFramework("ScreenCaptureKit"), .linkedFramework("Carbon")]
        ),
        .testTarget(name: "CaptureCoreTests", dependencies: ["CaptureCore"])
    ],
    swiftLanguageModes: [.v5]
)
