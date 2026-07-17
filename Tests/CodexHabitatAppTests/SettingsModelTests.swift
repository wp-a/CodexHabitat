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
    #expect(saved.widgetOrder == [.tokens, .context, .speed, .usage, .countdown])
    #expect(saved.scale == 1.5)
    #expect(saved.clickThrough)
}

@Test @MainActor
func overlayPlacementAndLockAreNormalizedAndPersisted() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatPlacementTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SettingsStore(root: root.appending(path: "Settings"))
    let model = HabitatAppModel(
        settingsStore: store,
        petRoot: root.appending(path: "Pets")
    )
    await model.load()

    model.setPositionLocked(true)
    model.setOverlayPosition(displayID: "display-2", x: 1.4, y: -0.2)
    await model.flushSettings()

    let saved = try await store.load()
    #expect(saved.positionLocked)
    #expect(saved.overlayPositions["display-2"] == OverlayPosition(x: 1, y: 0))
}

@Test @MainActor
func launchAtLoginPersistsOnlyAfterSystemRegistration() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatLoginItemTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SettingsStore(root: root.appending(path: "Settings"))
    let controller = FakeLaunchAtLoginController(status: .disabled)
    let model = HabitatAppModel(
        settingsStore: store,
        petRoot: root.appending(path: "Pets"),
        launchAtLoginController: controller
    )
    await model.load()

    model.setLaunchAtLogin(true)
    await model.flushSettings()

    #expect(controller.requests == [true])
    #expect(model.launchAtLoginStatus == .enabled)
    #expect(model.settings.launchAtLogin)
    #expect(try await store.load().launchAtLogin)
}

@Test @MainActor
func launchAtLoginFailureRollsBackTheSetting() async {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatLoginItemFailure-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let controller = FakeLaunchAtLoginController(status: .disabled, rejectsChanges: true)
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root.appending(path: "Settings")),
        petRoot: root.appending(path: "Pets"),
        launchAtLoginController: controller
    )
    await model.load()

    model.setLaunchAtLogin(true)

    #expect(model.launchAtLoginStatus == .disabled)
    #expect(!model.settings.launchAtLogin)
    #expect(model.errorMessage == "macOS could not update the login item.")
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
    #expect(model.petPresentations["resource-pet"] == HabitatPetPresentation(
        renderMode: .smooth,
        scale: 1.25
    ))
    #expect(model.petPresentations["test-pet"] == nil)
    let selectedPath = model.validPets.first?.packageURL.resolvingSymlinksInPath().path
    let localPath = localPetRoot.resolvingSymlinksInPath().path
    #expect(selectedPath?.hasPrefix(localPath) == true)
}

@Test @MainActor
func installedResourceThemesCanBeSelectedAndUninstallFallsBack() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatResourceThemeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let resourceRoot = root.appending(path: "Library", directoryHint: .isDirectory)
    try installResourcePetFixture(
        at: resourceRoot,
        packageID: "studio.example.custom-theme",
        petID: "resource-pet"
    )
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root.appending(path: "Settings")),
        petRoot: root.appending(path: "Pets"),
        resourceLibraryRoot: resourceRoot
    )
    await model.load()

    #expect(model.installedPackages.map(\.id) == ["studio.example.custom-theme"])
    #expect(model.availableThemes.map(\.id).contains("studio.example.custom-theme"))
    model.selectTheme("studio.example.custom-theme")
    #expect(model.settings.selectedThemeID == "studio.example.custom-theme")

    await model.uninstallResourcePackage(id: "studio.example.custom-theme")

    #expect(model.installedPackages.isEmpty)
    #expect(model.settings.selectedThemeID == "workbench")
    #expect(model.validPets.isEmpty)
}

@Test @MainActor
func duplicateResourceImportWaitsForExplicitReplacementApproval() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatResourceReplacement-\(UUID().uuidString)", directoryHint: .isDirectory)
    let exportURL = root.appending(path: "replacement.habitat-pack")
    defer { try? FileManager.default.removeItem(at: root) }
    let resourceRoot = root.appending(path: "Library", directoryHint: .isDirectory)
    try installResourcePetFixture(
        at: resourceRoot,
        packageID: "studio.example.replaceable",
        petID: "replaceable-pet"
    )
    let model = HabitatAppModel(
        settingsStore: SettingsStore(root: root.appending(path: "Settings")),
        petRoot: root.appending(path: "Pets"),
        resourceLibraryRoot: resourceRoot
    )
    await model.load()
    await model.exportResourcePackage(id: "studio.example.replaceable", to: exportURL)

    await model.importResourcePackage(from: exportURL)

    #expect(model.pendingReplacementArchiveURL == exportURL)
    #expect(model.resourceOperationState == .replacementRequired("replacement.habitat-pack"))

    await model.replacePendingResourcePackage()

    #expect(model.pendingReplacementArchiveURL == nil)
    #expect(model.resourceOperationState == .imported("Resource Pet Pack"))
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

@MainActor
private final class FakeLaunchAtLoginController: HabitatLaunchAtLoginControlling {
    var status: HabitatLaunchAtLoginStatus
    var requests: [Bool] = []
    var rejectsChanges: Bool

    init(status: HabitatLaunchAtLoginStatus, rejectsChanges: Bool = false) {
        self.status = status
        self.rejectsChanges = rejectsChanges
    }

    func setEnabled(_ enabled: Bool) throws -> HabitatLaunchAtLoginStatus {
        requests.append(enabled)
        guard !rejectsChanges else { throw FakeLoginItemError.rejected }
        status = enabled ? .enabled : .disabled
        return status
    }

    func openSystemSettings() {}
}

private enum FakeLoginItemError: Error {
    case rejected
}

private func installResourcePetFixture(
    at resourceRoot: URL,
    packageID: String = "studio.example.resource-pack",
    petID: String,
    rendering: String = "smooth",
    scale: Double = 1.25
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
            "rendering": rendering,
            "scale": scale,
        ]],
        "widgets": [],
    ]
    try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        .write(to: package.appending(path: "habitat.json"))
    try Data("MIT".utf8).write(to: package.appending(path: "LICENSE"))
    try FileManager.default.copyItem(
        at: petDirectory.appending(path: "spritesheet.png"),
        to: package.appending(path: "preview.png")
    )
}
