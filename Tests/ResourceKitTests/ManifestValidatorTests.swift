import Foundation
import HabitatCore
import Testing
@testable import ResourceKit

@Test
func validV1ManifestDecodesIntoTypedResourcesAndWidgets() throws {
    let manifest = try ManifestDecoder(runtimeVersion: "1.0.0").decode(validManifestData())

    #expect(manifest.schemaVersion == 1)
    #expect(manifest.id == "studio.example.workbench")
    #expect(manifest.assets.count == 2)
    #expect(manifest.widgets.map(\.id) == [.status, .usage, .clock, .pomodoro])
    #expect(manifest.colors.accent == "#14B8A6")
}

@Test
func optionalRichColorsRemainBackwardCompatible() throws {
    let legacy = try ManifestDecoder(runtimeVersion: "1.0.0").decode(validManifestData())
    #expect(legacy.colors.panel == nil)
    #expect(legacy.theme == nil)

    let rich = try ManifestDecoder(runtimeVersion: "1.0.0").decode(
        try mutatedValidManifest {
            var colors = $0["colors"] as? [String: Any] ?? [:]
            colors["panel"] = "#15102B"
            colors["panelAlt"] = "#241A44"
            colors["mutedText"] = "#B9A8D8"
            colors["secondary"] = "#FF2D95"
            colors["highlight"] = "#FFE14D"
            $0["colors"] = colors
        }
    )
    #expect(rich.colors.panel == "#15102B")
    #expect(rich.colors.panelAlt == "#241A44")
    #expect(rich.colors.mutedText == "#B9A8D8")
    #expect(rich.colors.secondary == "#FF2D95")
    #expect(rich.colors.highlight == "#FFE14D")

    #expect(throws: ManifestValidationError.invalidColorToken("secondary")) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                var colors = $0["colors"] as? [String: Any] ?? [:]
                colors["secondary"] = "var(--accent)"
                $0["colors"] = colors
            }
        )
    }
}

@Test
func optionalThemeAppearanceIsTypedBoundedAndReferencesDeclaredImage() throws {
    let validData = try mutatedValidManifest { $0["theme"] = validThemeObject() }
    let manifest = try ManifestDecoder(runtimeVersion: "1.0.0").decode(validData)
    #expect(manifest.theme?.category == .animeEnergy)
    #expect(manifest.theme?.styleFamily == .animeEnergy)
    #expect(manifest.theme?.background == "artwork/desk.png")
    #expect(manifest.theme?.artFocus == HabitatThemeFocalPoint(x: 0.72, y: 0.42))
    #expect(manifest.theme?.density == .comfortable)

    for (key, value) in [
        ("category", "unknownCategory"),
        ("styleFamily", "rawCSSFamily"),
        ("safeSide", "center"),
        ("density", "extraDense"),
    ] {
        #expect(throws: (any Error).self, "Expected unknown \(key) to fail") {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(
                try mutatedValidManifest {
                    var theme = validThemeObject()
                    theme[key] = value
                    $0["theme"] = theme
                }
            )
        }
    }

    for (key, value) in [
        ("backgroundStrength", 0.09),
        ("backgroundStrength", 0.71),
        ("panelOpacity", 0.64),
        ("panelOpacity", 1.01),
        ("blurRadius", -0.01),
        ("blurRadius", 24.01),
    ] {
        #expect(throws: (any Error).self, "Expected \(key)=\(value) to fail") {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(
                try mutatedValidManifest {
                    var theme = validThemeObject()
                    theme[key] = value
                    $0["theme"] = theme
                }
            )
        }
    }

    for (axis, value) in [("x", -0.01), ("x", 1.01), ("y", -0.01), ("y", 1.01)] {
        #expect(throws: (any Error).self, "Expected artFocus.\(axis)=\(value) to fail") {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(
                try mutatedValidManifest {
                    var theme = validThemeObject()
                    var artFocus = theme["artFocus"] as? [String: Any] ?? [:]
                    artFocus[axis] = value
                    theme["artFocus"] = artFocus
                    $0["theme"] = theme
                }
            )
        }
    }

    for background in [
        "/tmp/background.jpg", "../background.jpg", "https://example.com/background.jpg",
        "artwork/missing.jpg",
    ] {
        #expect(throws: (any Error).self, "Expected unsafe background to fail") {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(
                try mutatedValidManifest {
                    var theme = validThemeObject()
                    theme["background"] = background
                    $0["theme"] = theme
                }
            )
        }
    }

    #expect(throws: ManifestDecodingError.unknownField("$.theme.css")) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                var theme = validThemeObject()
                theme["css"] = "* { display: none }"
                $0["theme"] = theme
            }
        )
    }

    let finiteJSON = try #require(String(data: validData, encoding: .utf8))
    let nonFiniteJSON = finiteJSON.replacingOccurrences(
        of: "\"blurRadius\":10",
        with: "\"blurRadius\":1e309"
    )
    #expect(nonFiniteJSON != finiteJSON)
    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(Data(nonFiniteJSON.utf8))
    }
}

@Test
func metricWidgetConfigurationsDecodeAndValidateAsStaticData() throws {
    for (id, type) in [
        ("codex.tokens", "tokens"),
        ("codex.context", "context"),
        ("codex.speed", "speed"),
    ] {
        let data = try mutatedValidManifest {
            var widgets = $0["widgets"] as? [[String: Any]] ?? []
            widgets.append([
                "id": id,
                "anchor": "center",
                "position": ["x": 0.5, "y": 0.5],
                "configuration": ["type": type],
            ])
            $0["widgets"] = widgets
        }
        let manifest = try ManifestDecoder(runtimeVersion: "1.0.0").decode(data)
        #expect(manifest.widgets.last?.id.rawValue == id)
    }
}

@Test
func allCommittedInvalidFixturesAreRejected() throws {
    let directory = try #require(
        Bundle.module.url(
            forResource: "invalid-packs",
            withExtension: nil,
            subdirectory: "Fixtures"
        )
    )
    let fixtures = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }

    #expect(fixtures.count == 5)
    for fixture in fixtures {
        #expect(throws: (any Error).self, "Expected \(fixture.lastPathComponent) to fail") {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(Data(contentsOf: fixture))
        }
    }
}

@Test
func identityVersionLicenseColorsAndRuntimeAreStrictlyValidated() throws {
    let cases: [(String, Any)] = [
        ("id", "../escape"),
        ("version", "1.0"),
        ("version", "1.0.0-01"),
        ("minimumRuntimeVersion", "2.0.0"),
    ]
    for (key, value) in cases {
        #expect(throws: (any Error).self, "Expected \(key) to fail") {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(
                try mutatedValidManifest { $0[key] = value }
            )
        }
    }

    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                $0["license"] = ["spdx": "https://example.com/license", "file": "LICENSE"]
            }
        )
    }
    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                var colors = $0["colors"] as? [String: Any] ?? [:]
                colors["accent"] = "var(--accent)"
                $0["colors"] = colors
            }
        )
    }
}

@Test
func pathsWidgetIDsNumericBoundsAndUnknownNestedFieldsAreRejected() throws {
    for path in ["/tmp/preview.png", "../preview.png", "https://example.com/x.png", "~/.x.png"] {
        #expect(throws: (any Error).self) {
            try ManifestDecoder(runtimeVersion: "1.0.0").decode(
                try mutatedValidManifest { $0["preview"] = path }
            )
        }
    }
    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest { $0["preview"] = "Preview.PNG" }
        )
    }

    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                var widgets = $0["widgets"] as? [[String: Any]] ?? []
                widgets[0]["id"] = "custom.javascript"
                $0["widgets"] = widgets
            }
        )
    }
    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                var widgets = $0["widgets"] as? [[String: Any]] ?? []
                widgets[3]["configuration"] = [
                    "type": "pomodoro", "focusSeconds": 0, "restSeconds": 300,
                ]
                $0["widgets"] = widgets
            }
        )
    }
    #expect(throws: (any Error).self) {
        try ManifestDecoder(runtimeVersion: "1.0.0").decode(
            try mutatedValidManifest {
                var widgets = $0["widgets"] as? [[String: Any]] ?? []
                var position = widgets[0]["position"] as? [String: Any] ?? [:]
                position["expression"] = "screen.width / 2"
                widgets[0]["position"] = position
                $0["widgets"] = widgets
            }
        )
    }
}

@Test
func committedJSONSchemaMatchesTheRuntimeContract() throws {
    let schemaURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Schemas/habitat-pack-v1.schema.json")
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL))
    let schema = try #require(object as? [String: Any])
    let properties = try #require(schema["properties"] as? [String: Any])
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let widget = try #require(definitions["widget"] as? [String: Any])
    let widgetVariants = try #require(widget["oneOf"] as? [[String: Any]])
    let position = try #require(definitions["position"] as? [String: Any])
    let positionProperties = try #require(position["properties"] as? [String: Any])
    let x = try #require(positionProperties["x"] as? [String: Any])
    let pomodoro = try #require(definitions["pomodoroConfiguration"] as? [String: Any])
    let pomodoroProperties = try #require(pomodoro["properties"] as? [String: Any])
    let focusSeconds = try #require(pomodoroProperties["focusSeconds"] as? [String: Any])
    let theme = try #require(definitions["theme"] as? [String: Any])
    let themeProperties = try #require(theme["properties"] as? [String: Any])
    let backgroundStrength = try #require(themeProperties["backgroundStrength"] as? [String: Any])
    let panelOpacity = try #require(themeProperties["panelOpacity"] as? [String: Any])
    let blurRadius = try #require(themeProperties["blurRadius"] as? [String: Any])

    #expect(schema["additionalProperties"] as? Bool == false)
    #expect((properties["schemaVersion"] as? [String: Any])?["const"] as? Int == 1)
    #expect(widgetVariants.count == WidgetIdentifier.allCases.count)
    #expect(x["minimum"] as? Int == 0)
    #expect(x["maximum"] as? Int == 1)
    #expect(focusSeconds["minimum"] as? Int == 60)
    #expect(focusSeconds["maximum"] as? Int == 86_400)
    #expect((properties["theme"] as? [String: Any])?["$ref"] as? String == "#/$defs/theme")
    #expect(backgroundStrength["minimum"] as? Double == 0.10)
    #expect(backgroundStrength["maximum"] as? Double == 0.70)
    #expect(panelOpacity["minimum"] as? Double == 0.65)
    #expect(panelOpacity["maximum"] as? Double == 1.0)
    #expect(blurRadius["minimum"] as? Int == 0)
    #expect(blurRadius["maximum"] as? Int == 24)
}

private func validManifestData() throws -> Data {
    let url = try #require(
        Bundle.module.url(
            forResource: "habitat",
            withExtension: "json",
            subdirectory: "Fixtures/valid-pack"
        )
    )
    return try Data(contentsOf: url)
}

private func mutatedValidManifest(
    _ mutate: (inout [String: Any]) -> Void
) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: validManifestData())
    var manifest = try #require(object as? [String: Any])
    mutate(&manifest)
    return try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
}

private func validThemeObject() -> [String: Any] {
    [
        "category": "animeEnergy",
        "styleFamily": "animeEnergy",
        "background": "artwork/desk.png",
        "artFocus": ["x": 0.72, "y": 0.42],
        "safeSide": "leading",
        "backgroundStrength": 0.42,
        "panelOpacity": 0.88,
        "blurRadius": 10.0,
        "density": "comfortable",
    ]
}
