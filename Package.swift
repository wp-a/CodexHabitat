// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexHabitat",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HabitatCore", targets: ["HabitatCore"]),
        .library(name: "CodexConnector", targets: ["CodexConnector"]),
        .library(name: "PetRuntime", targets: ["PetRuntime"]),
        .library(name: "WidgetRuntime", targets: ["WidgetRuntime"]),
        .library(name: "ResourceKit", targets: ["ResourceKit"]),
        .library(name: "OverlayHost", targets: ["OverlayHost"]),
        .executable(name: "CodexHabitatApp", targets: ["CodexHabitatApp"]),
        .executable(name: "CodexHabitatThemeBridge", targets: ["CodexHabitatThemeBridge"]),
    ],
    targets: [
        .target(name: "HabitatCore"),
        .target(name: "CodexConnector", dependencies: ["HabitatCore"]),
        .target(name: "PetRuntime", dependencies: ["HabitatCore"]),
        .target(name: "WidgetRuntime", dependencies: ["HabitatCore"]),
        .target(name: "ResourceKit", dependencies: ["HabitatCore"]),
        .target(name: "OverlayHost", dependencies: ["HabitatCore"]),
        .executableTarget(
            name: "CodexHabitatApp",
            dependencies: [
                "HabitatCore",
                "CodexConnector",
                "PetRuntime",
                "WidgetRuntime",
                "ResourceKit",
                "OverlayHost",
            ]
        ),
        .executableTarget(name: "CodexHabitatThemeBridge", dependencies: ["HabitatCore"]),
        .testTarget(name: "HabitatCoreTests", dependencies: ["HabitatCore"]),
        .testTarget(name: "CodexConnectorTests", dependencies: ["CodexConnector"]),
    ],
    swiftLanguageModes: [.v6]
)
