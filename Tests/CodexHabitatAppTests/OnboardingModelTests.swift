import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test @MainActor
func onboardingDiscoversAPetAndCompletesInExactlyThreeSteps() async throws {
    try await withTemporaryAppRoots { settingsRoot, petRoot in
        try installValidPetFixture(at: petRoot)
        let model = HabitatAppModel(
            settingsStore: SettingsStore(root: settingsRoot),
            petRoot: petRoot
        )

        await model.load()

        #expect(model.validPets.map(\.manifest?.id) == ["test-pet"])
        #expect(model.settings.selectedPetID == "test-pet")
        #expect(model.settings.selectedThemeID == "workbench")
        #expect(model.settings.widgetOrder == [.status, .usage, .clock, .pomodoro])
        #expect(model.requiresAccount == false)
        #expect(model.requiresOnboarding)
        #expect(model.onboardingStep == .habitat)

        #expect(await model.advanceOnboarding() == false)
        #expect(model.onboardingStep == .pet)
        #expect(await model.advanceOnboarding() == false)
        #expect(model.onboardingStep == .widgets)
        #expect(await model.advanceOnboarding() == true)
        #expect(model.settings.onboardingCompleted)
        #expect(model.requiresOnboarding == false)
    }
}

@Test @MainActor
func completedOnboardingAndSelectionsRestoreWithoutAnAccount() async throws {
    try await withTemporaryAppRoots { settingsRoot, petRoot in
        try installValidPetFixture(at: petRoot)
        let store = SettingsStore(root: settingsRoot)
        let model = HabitatAppModel(settingsStore: store, petRoot: petRoot)
        await model.load()
        model.selectTheme("night-shift")
        model.setWidget(.usage, enabled: false)
        _ = await model.advanceOnboarding()
        _ = await model.advanceOnboarding()
        _ = await model.advanceOnboarding()

        let restored = HabitatAppModel(settingsStore: store, petRoot: petRoot)
        await restored.load()

        #expect(restored.requiresOnboarding == false)
        #expect(restored.requiresAccount == false)
        #expect(restored.settings.selectedPetID == "test-pet")
        #expect(restored.settings.selectedThemeID == "night-shift")
        #expect(restored.settings.widgetOrder == [.status, .clock, .pomodoro])
    }
}

@MainActor
private func withTemporaryAppRoots(
    _ operation: (URL, URL) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatAppTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try await operation(root.appending(path: "Settings"), root.appending(path: "Pets"))
}

private func installValidPetFixture(at petRoot: URL) throws {
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
