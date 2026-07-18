import Foundation
import HabitatCore
import ResourceKit
import Testing
@testable import CodexHabitatApp

@Test @MainActor
func themeStudioTracksDirtyDraftClampsAppearanceAndRequiresDiscardConfirmation() {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioDraft-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work")
    )

    #expect(model.id == model.id)
    #expect(model.state == .editing)
    #expect(!model.isDirty)
    model.name = "My Local Theme"
    model.setBackgroundStrength(4)
    model.setPanelOpacity(0)
    model.setBlurRadius(100)
    model.setArtFocus(x: -1, y: 2)
    model.setHomeStrength(4)
    model.setTaskStrength(0)
    model.setSidebarOpacity(4)
    model.setHeaderOpacity(0)
    model.setComposerOpacity(4)

    #expect(model.isDirty)
    #expect(model.backgroundStrength == 0.70)
    #expect(model.panelOpacity == 0.65)
    #expect(model.blurRadius == 24)
    #expect(model.artFocus == HabitatThemeFocalPoint(x: 0, y: 1))
    #expect(model.homeStrength == 0.85)
    #expect(model.taskStrength == 0.10)
    #expect(model.sidebarOpacity == 1.0)
    #expect(model.headerOpacity == 0.40)
    #expect(model.composerOpacity == 1.0)
    #expect(!model.requestClose())
    #expect(model.showsDiscardConfirmation)

    model.discardDraft()
    #expect(!model.isDirty)
    #expect(!model.showsDiscardConfirmation)
}

@Test @MainActor
func themeStudioSelectsLocalImageSuggestsPaletteAndSavesThroughInstaller() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioSave-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let imageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let model = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "Work")
    )
    model.name = "Ocean Workshop"
    model.author = "Local Artist"
    model.setStyleFamily(.retroMessenger)
    model.setSafeSide(.center)
    model.setHomeMode(.framed)
    model.setTaskMode(.banner)
    model.setChromeMaterial(.glass)
    model.setHomeStrength(0.63)
    model.setTaskStrength(0.31)
    model.setSidebarOpacity(0.77)
    model.setHeaderOpacity(0.68)
    model.setComposerOpacity(0.91)
    model.setDensity(.compact)

    try model.selectImage(imageURL)
    #expect(model.sourceImageURL == imageURL)
    #expect(model.palette != nil)
    await model.saveLocally()

    guard case let .saved(id) = model.state else {
        Issue.record("Expected saved state, got \(model.state)")
        return
    }
    let installed = InstalledPackageLibrary(root: library, runtimeVersion: "1.0.0")
        .currentPackages()
    #expect(installed.map(\.id) == [id])
    #expect(installed.first?.manifest.theme?.background == "background.jpg")
    let appearance = try #require(installed.first?.manifest.theme)
    #expect(appearance.styleFamily == .retroMessenger)
    #expect(appearance.safeSide == .center)
    #expect(appearance.homeMode == .framed)
    #expect(appearance.taskMode == .banner)
    #expect(appearance.chromeMaterial == .glass)
    #expect(appearance.homeStrength == 0.63)
    #expect(appearance.taskStrength == 0.31)
    #expect(appearance.sidebarOpacity == 0.77)
    #expect(appearance.headerOpacity == 0.68)
    #expect(appearance.composerOpacity == 0.91)
    #expect(appearance.density == .compact)
    #expect(!model.isDirty)

    let appModel = HabitatAppModel(
        settingsStore: SettingsStore(root: root.appending(path: "Settings")),
        petRoot: root.appending(path: "Pets"),
        resourceLibraryRoot: library
    )
    await appModel.load()
    appModel.selectTheme(id)
    #expect(appModel.selectedThemeSupportsCodexBridge)
    #expect(appModel.codexBridgeThemeIDs.contains(id))
}

@Test @MainActor
func themeStudioShowsAdjacentIdentityValidationErrors() async {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioValidation-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work")
    )
    model.name = String(repeating: "n", count: 101)
    model.author = "Unsafe\u{0000}Author"

    await model.saveLocally()

    #expect(model.nameValidationMessage == L10n.text(
        "Theme names must be 100 characters or fewer and contain no control characters."
    ))
    #expect(model.authorValidationMessage == L10n.text(
        "Authors must be 100 characters or fewer and contain no control characters."
    ))
}

@Test @MainActor
func installedCustomThemeReopensAsCleanStronglyTypedStudioDraft() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioEdit-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let sourceImageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)
    let creator = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "Work")
    )
    creator.name = "Editable Theme"
    creator.author = "Local Artist"
    creator.setStyleFamily(.retroMessenger)
    creator.setSafeSide(.trailing)
    creator.setDensity(.compact)
    creator.setHomeMode(.framed)
    creator.setTaskMode(.banner)
    creator.setChromeMaterial(.glass)
    creator.setArtFocus(x: 0.23, y: 0.67)
    creator.setBackgroundStrength(0.51)
    creator.setPanelOpacity(0.79)
    creator.setBlurRadius(13)
    creator.setHomeStrength(0.62)
    creator.setTaskStrength(0.28)
    creator.setSidebarOpacity(0.74)
    creator.setHeaderOpacity(0.69)
    creator.setComposerOpacity(0.91)
    try creator.selectImage(sourceImageURL)
    let expectedPalette = try #require(creator.palette)
    await creator.saveLocally()
    let themeID = try #require(creator.state.savedID)
    let petRoot = root.appending(path: "Pets", directoryHint: .isDirectory)
    try installThemeStudioPetFixture(at: petRoot)
    let settingsStore = SettingsStore(root: root.appending(path: "Settings"))
    var settings = HabitatSettings.default
    settings.themePetPairings[themeID] = "test-pet"
    try await settingsStore.save(settings)

    let appModel = HabitatAppModel(
        settingsStore: settingsStore,
        petRoot: petRoot,
        resourceLibraryRoot: library
    )
    await appModel.load()

    let editor = try #require(appModel.makeThemeStudioModel(editingThemeID: themeID))
    #expect(editor.name == "Editable Theme")
    #expect(editor.author == "Local Artist")
    #expect(editor.sourceImageURL?.standardizedFileURL.path.hasPrefix(
        library.standardizedFileURL.path + "/"
    ) == true)
    #expect(editor.palette == expectedPalette)
    #expect(editor.styleFamily == .retroMessenger)
    #expect(editor.safeSide == .trailing)
    #expect(editor.density == .compact)
    #expect(editor.homeMode == .framed)
    #expect(editor.taskMode == .banner)
    #expect(editor.chromeMaterial == .glass)
    #expect(editor.artFocus == HabitatThemeFocalPoint(x: 0.23, y: 0.67))
    #expect(editor.backgroundStrength == 0.51)
    #expect(editor.panelOpacity == 0.79)
    #expect(editor.blurRadius == 13)
    #expect(editor.homeStrength == 0.62)
    #expect(editor.taskStrength == 0.28)
    #expect(editor.sidebarOpacity == 0.74)
    #expect(editor.headerOpacity == 0.69)
    #expect(editor.composerOpacity == 0.91)
    #expect(editor.pairedPetID == "test-pet")
    #expect(!editor.isDirty)
    #expect(appModel.makeThemeStudioModel(editingThemeID: "workbench") == nil)
}

@Test @MainActor
func themeStudioRequiresExplicitConfirmationBeforeReplacingSlugCollision() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioCollision-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let imageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)

    let original = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "OriginalWork")
    )
    original.name = "Slug Collision"
    original.author = "Original Author"
    try original.selectImage(imageURL)
    await original.saveLocally()
    let themeID = try #require(original.state.savedID)

    let replacement = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "ReplacementWork")
    )
    replacement.name = "Slug Collision"
    replacement.author = "Replacement Author"
    try replacement.selectImage(imageURL)

    await replacement.saveLocally()

    #expect(replacement.state == .replacementRequired(themeID))
    #expect(InstalledPackageLibrary(root: library, runtimeVersion: "1.0.0")
        .currentPackages().first?.manifest.author == "Original Author")

    await replacement.replaceExistingTheme()

    #expect(replacement.state == .saved(themeID))
    #expect(InstalledPackageLibrary(root: library, runtimeVersion: "1.0.0")
        .currentPackages().first?.manifest.author == "Replacement Author")
}

private func installThemeStudioPetFixture(at petRoot: URL) throws {
    let testsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fixture = testsRoot.appending(
        path: "PetRuntimeTests/Fixtures/valid-pet",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: petRoot, withIntermediateDirectories: true)
    try FileManager.default.copyItem(
        at: fixture,
        to: petRoot.appending(path: "test-pet", directoryHint: .isDirectory)
    )
}

private extension ThemeStudioState {
    var savedID: String? {
        guard case let .saved(id) = self else { return nil }
        return id
    }
}
