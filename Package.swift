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
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            exact: "0.9.20"
        ),
    ],
    targets: [
        .target(name: "HabitatCore"),
        .target(name: "CodexConnector", dependencies: ["HabitatCore"]),
        .target(name: "PetRuntime", dependencies: ["HabitatCore"]),
        .target(name: "WidgetRuntime", dependencies: ["HabitatCore"]),
        .target(
            name: "ResourceKit",
            dependencies: [
                "HabitatCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
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
            ],
            resources: [.copy("Resources")]
        ),
        .executableTarget(name: "CodexHabitatThemeBridge", dependencies: ["HabitatCore"]),
        .testTarget(name: "HabitatCoreTests", dependencies: ["HabitatCore"]),
        .testTarget(
            name: "CodexConnectorTests",
            dependencies: ["CodexConnector"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "PetRuntimeTests",
            dependencies: ["PetRuntime"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "OverlayHostTests", dependencies: ["OverlayHost"]),
        .testTarget(
            name: "CodexHabitatAppTests",
            dependencies: ["CodexHabitatApp", "HabitatCore", "PetRuntime"]
        ),
        .testTarget(
            name: "WidgetRuntimeTests",
            dependencies: ["WidgetRuntime", "HabitatCore"]
        ),
        .testTarget(
            name: "ResourceKitTests",
            dependencies: [
                "ResourceKit",
                "HabitatCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
