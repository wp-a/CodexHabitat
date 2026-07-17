import Foundation

public enum ManifestDecodingError: Error, Equatable, Sendable {
    case rootMustBeObject
    case unknownField(String)
}

public struct ManifestDecoder: Sendable {
    private let validator: ManifestValidator

    public init(runtimeVersion: String) {
        validator = ManifestValidator(runtimeVersion: runtimeVersion)
    }

    public func decode(_ data: Data) throws -> HabitatManifest {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw ManifestDecodingError.rootMustBeObject
        }
        try ManifestShapeValidator.validate(root)
        let manifest = try JSONDecoder().decode(HabitatManifest.self, from: data)
        try validator.validate(manifest)
        return manifest
    }
}

private enum ManifestShapeValidator {
    private static let rootKeys: Set<String> = [
        "schemaVersion", "id", "name", "version", "author", "license",
        "minimumRuntimeVersion", "modes", "preview", "colors", "assets",
        "pets", "widgets", "theme",
    ]

    static func validate(_ root: [String: Any]) throws {
        try validateKeys(root, allowed: rootKeys, path: "$")
        try validateObject(root["license"], allowed: ["spdx", "file"], path: "$.license")
        try validateObject(
            root["colors"],
            allowed: [
                "surface", "panel", "panelAlt", "text", "mutedText", "accent",
                "secondary", "highlight", "attention", "error",
            ],
            path: "$.colors"
        )
        try validateObject(
            root["theme"],
            allowed: [
                "category", "styleFamily", "background", "artFocus", "safeSide",
                "backgroundStrength", "panelOpacity", "blurRadius", "density",
            ],
            path: "$.theme"
        )
        if let theme = root["theme"] as? [String: Any] {
            try validateObject(
                theme["artFocus"],
                allowed: ["x", "y"],
                path: "$.theme.artFocus"
            )
        }

        if let assets = root["assets"] as? [[String: Any]] {
            for (index, asset) in assets.enumerated() {
                let path = "$.assets[\(index)]"
                switch asset["type"] as? String {
                case "image":
                    try validateKeys(
                        asset,
                        allowed: ["type", "id", "path", "sha256", "rendering"],
                        path: path
                    )
                case "font":
                    try validateKeys(
                        asset,
                        allowed: ["type", "id", "path", "sha256"],
                        path: path
                    )
                default:
                    try validateKeys(asset, allowed: ["type"], path: path)
                }
            }
        }

        if let pets = root["pets"] as? [[String: Any]] {
            for (index, pet) in pets.enumerated() {
                try validateKeys(
                    pet,
                    allowed: ["id", "path", "rendering", "scale"],
                    path: "$.pets[\(index)]"
                )
            }
        }

        if let widgets = root["widgets"] as? [[String: Any]] {
            for (index, widget) in widgets.enumerated() {
                let path = "$.widgets[\(index)]"
                try validateKeys(
                    widget,
                    allowed: ["id", "anchor", "position", "configuration"],
                    path: path
                )
                try validateObject(
                    widget["position"],
                    allowed: ["x", "y"],
                    path: "\(path).position"
                )
                if let configuration = widget["configuration"] as? [String: Any] {
                    let configurationPath = "\(path).configuration"
                    switch configuration["type"] as? String {
                    case "status":
                        try validateKeys(
                            configuration,
                            allowed: ["type", "showsConnectionHealth"],
                            path: configurationPath
                        )
                    case "usage":
                        try validateKeys(
                            configuration,
                            allowed: ["type", "bucket"],
                            path: configurationPath
                        )
                    case "tokens", "context", "speed":
                        try validateKeys(
                            configuration,
                            allowed: ["type"],
                            path: configurationPath
                        )
                    case "clock":
                        try validateKeys(
                            configuration,
                            allowed: ["type", "uses24HourClock"],
                            path: configurationPath
                        )
                    case "pomodoro":
                        try validateKeys(
                            configuration,
                            allowed: ["type", "focusSeconds", "restSeconds"],
                            path: configurationPath
                        )
                    case "countdown":
                        try validateKeys(
                            configuration,
                            allowed: ["type", "durationSeconds"],
                            path: configurationPath
                        )
                    default:
                        try validateKeys(configuration, allowed: ["type"], path: configurationPath)
                    }
                }
            }
        }
    }

    private static func validateObject(
        _ value: Any?,
        allowed: Set<String>,
        path: String
    ) throws {
        guard let object = value as? [String: Any] else { return }
        try validateKeys(object, allowed: allowed, path: path)
    }

    private static func validateKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        path: String
    ) throws {
        if let unknown = object.keys.sorted().first(where: { !allowed.contains($0) }) {
            throw ManifestDecodingError.unknownField("\(path).\(unknown)")
        }
    }
}
