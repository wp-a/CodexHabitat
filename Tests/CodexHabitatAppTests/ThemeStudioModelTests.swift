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

    #expect(model.isDirty)
    #expect(model.backgroundStrength == 0.70)
    #expect(model.panelOpacity == 0.65)
    #expect(model.blurRadius == 24)
    #expect(model.artFocus == HabitatThemeFocalPoint(x: 0, y: 1))
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
