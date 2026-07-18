import Foundation
import Testing
@testable import HabitatCore

@Test
func defaultSettingsKeepRiskyFeaturesDisabled() {
    let settings = HabitatSettings.default

    #expect(settings.schemaVersion == 5)
    #expect(settings.selectedThemeID == "workbench")
    #expect(settings.themePetPairings.isEmpty)
    #expect(settings.scale == 1)
    #expect(settings.themeBridgeEnabled == false)
    #expect(settings.launchAtLogin == false)
    #expect(settings.positionLocked == false)
    #expect(settings.onboardingCompleted == false)
}

@Test
func schemaThreeOldDefaultsMigrateToUsefulCodexMetrics() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        let data = Data(
            """
            {
              "schemaVersion": 3,
              "widgetOrder": ["codex.status", "codex.usage", "system.clock", "timer.pomodoro"]
            }
            """.utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appending(path: "Settings.json"))

        let settings = try await store.load()

        #expect(settings.schemaVersion == 5)
        #expect(settings.widgetOrder == [.status, .tokens, .context, .speed, .usage])
    }
}

@Test
func schemaThreeCustomWidgetOrderIsPreserved() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        let data = Data(
            """
            {
              "schemaVersion": 3,
              "widgetOrder": ["codex.status", "system.clock"]
            }
            """.utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appending(path: "Settings.json"))

        let settings = try await store.load()

        #expect(settings.widgetOrder == [.status, .clock])
    }
}

@Test
func settingsRoundTripThroughInjectedRoot() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        var settings = HabitatSettings.default
        settings.selectedPetID = "test-pet"
        settings.selectedThemeID = "night-shift"
        settings.themePetPairings = ["night-shift": "test-pet"]
        settings.scale = 1.25
        settings.clickThrough = true
        settings.positionLocked = true
        settings.overlayPositions["display-1"] = OverlayPosition(x: 0.75, y: 0.2)

        try await store.save(settings)

        #expect(try await store.load() == settings)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Settings.json").path))
    }
}

@Test
func schemaFourMigratesWithNoThemePetPairings() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        let data = Data(
            """
            {
              "schemaVersion": 4,
              "selectedPetID": "test-pet",
              "selectedThemeID": "night-shift"
            }
            """.utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appending(path: "Settings.json"))

        let settings = try await store.load()

        #expect(settings.schemaVersion == 5)
        #expect(settings.themePetPairings.isEmpty)
    }
}

@Test
func decoderIgnoresUnknownFields() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "selectedThemeID": "arcade-signal",
              "futureSetting": { "enabled": true }
            }
            """.utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appending(path: "Settings.json"))

        let settings = try await store.load()

        #expect(settings.selectedThemeID == "arcade-signal")
        #expect(settings.widgetOrder == HabitatSettings.default.widgetOrder)
    }
}

@Test
func schemaZeroMigratesWithThemeBridgeDisabled() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        let data = Data(
            """
            {
              "schemaVersion": 0,
              "selectedPetID": "test-pet",
              "selectedThemeID": "night-shift",
              "themeBridgeEnabled": true
            }
            """.utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appending(path: "Settings.json"))

        let settings = try await store.load()

        #expect(settings.schemaVersion == 5)
        #expect(settings.selectedPetID == "test-pet")
        #expect(settings.selectedThemeID == "night-shift")
        #expect(settings.themeBridgeEnabled == false)
    }
}

@Test
func schemaOnePreservesThemeBridgeAndDefaultsOnboardingToIncomplete() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "selectedThemeID": "night-shift",
              "themeBridgeEnabled": true
            }
            """.utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appending(path: "Settings.json"))

        let settings = try await store.load()

        #expect(settings.schemaVersion == 5)
        #expect(settings.themeBridgeEnabled)
        #expect(settings.onboardingCompleted == false)
        #expect(settings.positionLocked == false)
    }
}

@Test
func savedSettingsAndDirectoriesUsePrivatePermissions() async throws {
    try await withTemporarySettingsRoot { root in
        let store = SettingsStore(root: root)
        try await store.save(.default)

        let fileMode = try permissions(of: root.appending(path: "Settings.json"))
        let directoryMode = try permissions(of: root)

        #expect(fileMode == 0o600)
        #expect(directoryMode == 0o700)
    }
}

private func withTemporarySettingsRoot(
    _ operation: (URL) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    try await operation(root)
}

private func permissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    return permissions.intValue & 0o777
}
