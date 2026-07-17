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

@Test @MainActor
func installedResourcePackPetsJoinLocalDiscoveryWithoutReplacingLocalIDs() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatResourcePetTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let settingsRoot = root.appending(path: "Settings")
    let localPetRoot = root.appending(path: "Pets")
    let resourceRoot = root.appending(path: "Library")
    try installSettingsPetFixture(at: localPetRoot)
    try installResourcePetFixture(at: resourceRoot, petID: "resource-pet")
    try installResourcePetFixture(at: resourceRoot, packageID: "studio.example.duplicate", petID: "test-pet")

    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: settingsRoot),
        petRoot: localPetRoot,
        resourceLibraryRoot: resourceRoot
    )
    await model.load()

    #expect(model.validPets.compactMap(\.manifest?.id) == ["test-pet", "resource-pet"])
    let selectedPath = model.validPets.first?.packageURL.resolvingSymlinksInPath().path
    let localPath = localPetRoot.resolvingSymlinksInPath().path
    #expect(selectedPath?.hasPrefix(localPath) == true)
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

private func installResourcePetFixture(
    at resourceRoot: URL,
    packageID: String = "studio.example.resource-pack",
    petID: String
) throws {
    let package = resourceRoot.appending(
        path: "\(packageID)/1.0.0",
        directoryHint: .isDirectory
    )
    let petDirectory = package.appending(path: "pets/\(petID)", directoryHint: .isDirectory)
    let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fixture = testsRoot.appending(path: "PetRuntimeTests/Fixtures/valid-pet", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: petDirectory.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.copyItem(at: fixture, to: petDirectory)
    let petJSON = petDirectory.appending(path: "pet.json")
    var petObject = try JSONSerialization.jsonObject(with: Data(contentsOf: petJSON)) as! [String: Any]
    petObject["id"] = petID
    try JSONSerialization.data(withJSONObject: petObject, options: [.sortedKeys]).write(to: petJSON)

    let manifest: [String: Any] = [
        "schemaVersion": 1,
        "id": packageID,
        "name": "Resource Pet Pack",
        "version": "1.0.0",
        "author": "Habitat",
        "license": ["spdx": "MIT", "file": "LICENSE"],
        "minimumRuntimeVersion": "1.0.0",
        "modes": ["light"],
        "preview": "preview.png",
        "colors": [
            "surface": "#FFFFFF", "text": "#111111", "accent": "#008080",
            "attention": "#D97706", "error": "#D64545",
        ],
        "assets": [],
        "pets": [[
            "id": petID,
            "path": "pets/\(petID)",
            "rendering": "pixelated",
            "scale": 1.0,
        ]],
        "widgets": [],
    ]
    try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        .write(to: package.appending(path: "habitat.json"))
}
