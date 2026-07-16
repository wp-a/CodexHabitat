import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test @MainActor
func settingsChangesUseKnownThemesWidgetsAndSafeScaleBounds() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatSettingsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SettingsStore(root: root.appending(path: "Settings"))
    let model = HabitatAppModel(
        settingsStore: store,
        petRoot: root.appending(path: "Pets")
    )
    await model.load()

    #expect(HabitatThemeDescriptor.builtIn.map(\.id) == [
        "workbench", "night-shift", "arcade-signal", "quiet-garden",
    ])
    model.selectTheme("unknown-theme")
    #expect(model.settings.selectedThemeID == "workbench")
    model.selectTheme("arcade-signal")
    model.setWidget(.countdown, enabled: true)
    model.setWidget(.status, enabled: false)
    model.setScale(4)
    model.setClickThrough(true)
    await model.flushSettings()

    let saved = try await store.load()
    #expect(saved.selectedThemeID == "arcade-signal")
    #expect(saved.widgetOrder == [.usage, .clock, .pomodoro, .countdown])
    #expect(saved.scale == 1.5)
    #expect(saved.clickThrough)
}

@Test @MainActor
func unavailableStoredPetFallsBackToTheFirstValidDiscovery() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatPetFallbackTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let settingsRoot = root.appending(path: "Settings")
    let petRoot = root.appending(path: "Pets")
    try installSettingsPetFixture(at: petRoot)
    let store = SettingsStore(root: settingsRoot)
    var settings = HabitatSettings.default
    settings.selectedPetID = "missing-pet"
    try await store.save(settings)

    let model = HabitatAppModel(settingsStore: store, petRoot: petRoot)
    await model.load()

    #expect(model.settings.selectedPetID == "test-pet")
    #expect(model.validPets.count == 1)
}

private func installSettingsPetFixture(at petRoot: URL) throws {
    let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fixture = testsRoot.appending(path: "PetRuntimeTests/Fixtures/valid-pet", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: petRoot, withIntermediateDirectories: true)
    try FileManager.default.copyItem(
        at: fixture,
        to: petRoot.appending(path: "test-pet", directoryHint: .isDirectory)
    )
}
