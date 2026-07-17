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

    #expect(schema["additionalProperties"] as? Bool == false)
    #expect((properties["schemaVersion"] as? [String: Any])?["const"] as? Int == 1)
    #expect(widgetVariants.count == WidgetIdentifier.allCases.count)
    #expect(x["minimum"] as? Int == 0)
    #expect(x["maximum"] as? Int == 1)
    #expect(focusSeconds["minimum"] as? Int == 60)
    #expect(focusSeconds["maximum"] as? Int == 86_400)
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
