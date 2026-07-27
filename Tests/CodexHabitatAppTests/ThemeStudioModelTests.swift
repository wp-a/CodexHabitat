import Foundation
import HabitatCore
import ResourceKit
import Testing
@testable import CodexHabitatApp

@Test
func themeStudioDoesNotExposeLegacyDeadAppearanceSliders() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemeStudioView.swift"
        ),
        encoding: .utf8
    )

    #expect(!source.contains("\"Background strength\","))
    #expect(!source.contains("\"Panel opacity\","))
    #expect(!source.contains("\"Home content width\","))
    #expect(!source.contains("value: model.homeContentWidth"))
    #expect(!source.contains("setter: model.setHomeContentWidth"))
}

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
    model.setHomeArtFocus(x: -1, y: 2)
    model.setTaskArtFocus(x: 2, y: -1)
    model.setHomeArtScale(4)
    model.setTaskArtScale(0)
    model.setTaskSidebarOpacity(4)
    model.setTaskHeaderOpacity(0)
    model.setHomeContentOpacity(4)
    model.setTaskContentOpacity(0)
    model.setHomeContentWidth(4)
    model.setVignetteStrength(-1)

    #expect(model.isDirty)
    #expect(model.backgroundStrength == 0.70)
    #expect(model.panelOpacity == 0.65)
    #expect(model.blurRadius == 24)
    #expect(model.artFocus == HabitatThemeFocalPoint(x: 0, y: 1))
    #expect(model.homeStrength == 0.85)
    #expect(model.taskStrength == 0.10)
    #expect(model.sidebarOpacity == 1.0)
    #expect(model.headerOpacity == 0.0)
    #expect(model.composerOpacity == 1.0)
    #expect(model.homeArtFocus == HabitatThemeFocalPoint(x: 0, y: 1))
    #expect(model.taskArtFocus == HabitatThemeFocalPoint(x: 1, y: 0))
    #expect(model.homeArtScale == 1.35)
    #expect(model.taskArtScale == 1.0)
    #expect(model.taskSidebarOpacity == 0.90)
    #expect(model.taskHeaderOpacity == 0.54)
    #expect(model.homeContentOpacity == 0.78)
    #expect(model.taskContentOpacity == 0.60)
    #expect(model.homeContentWidth == 0.68)
    #expect(model.vignetteStrength == 0.0)
    #expect(!model.requestClose())
    #expect(model.showsDiscardConfirmation)

    model.discardDraft()
    #expect(!model.isDirty)
    #expect(!model.showsDiscardConfirmation)
}

@Test @MainActor
func themeStudioOnlyEnablesPersistenceForACompleteValidDraft() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioPersistence-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations()
    )

    #expect(!model.canPersistDraft)
    #expect(model.persistenceRequirementMessage == L10n.text("Enter a theme name."))
    model.name = "Complete Theme"
    #expect(!model.canPersistDraft)
    #expect(model.persistenceRequirementMessage == L10n.text("Choose a local background image."))

    try await model.selectImage(root.appending(path: "local-background.jpg"))
    #expect(model.canPersistDraft)
    #expect(model.persistenceRequirementMessage == nil)

    model.author = String(repeating: "A", count: 101)
    #expect(!model.canPersistDraft)
    #expect(model.persistenceRequirementMessage == L10n.text(
        "Authors must be 100 characters or fewer and contain no control characters."
    ))
    #expect(!model.validateDraftForPersistence())
    #expect(model.authorValidationMessage != nil)
    guard case .validationFailure = model.state else {
        Issue.record("Expected validation failure, got \(model.state)")
        return
    }
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
    model.setArtFocus(x: 0.2346, y: 0.6746)
    model.setHomeArtFocus(x: 0.1846, y: 0.6246)
    model.setTaskArtFocus(x: 0.2746, y: 0.5746)
    model.setHomeArtScale(1.14)
    model.setTaskArtScale(1.06)
    model.setTaskSidebarOpacity(0.78)
    model.setTaskHeaderOpacity(0.71)
    model.setHomeContentOpacity(0.57)
    model.setTaskContentOpacity(0.74)
    model.setHomeContentWidth(0.59)
    model.setVignetteStrength(0.43)
    model.setDensity(.compact)

    try await model.selectImage(imageURL)
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
    #expect(appearance.artFocus == HabitatThemeFocalPoint(x: 0.23, y: 0.67))
    #expect(appearance.homeArtFocus == HabitatThemeFocalPoint(x: 0.18, y: 0.62))
    #expect(appearance.taskArtFocus == HabitatThemeFocalPoint(x: 0.27, y: 0.57))
    #expect(appearance.homeArtScale == 1.14)
    #expect(appearance.taskArtScale == 1.06)
    #expect(appearance.taskSidebarOpacity == 0.78)
    #expect(appearance.taskHeaderOpacity == 0.71)
    #expect(appearance.homeContentOpacity == 0.57)
    #expect(appearance.taskContentOpacity == 0.74)
    #expect(appearance.homeContentWidth == 0.59)
    #expect(appearance.vignetteStrength == 0.43)
    #expect(appearance.density == .compact)
    #expect(!model.isDirty)
    #expect(!model.canUndo)
    #expect(!model.canRedo)

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
func discardedDraftIgnoresAStaleImageSelectionSuccess() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioStaleImageSuccess-\(UUID().uuidString)")
    let paletteGate = ThemeStudioOperationGate<HabitatThemePalette>()
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations(paletteGate: paletteGate)
    )
    model.name = "Temporary name"
    let selectedURL = root.appending(path: "pending.jpg")

    let selection = Task { try await model.selectImage(selectedURL) }
    await paletteGate.waitUntilStarted()
    model.discardDraft()
    paletteGate.succeed(testThemePalette)
    try await selection.value

    #expect(model.draft == ThemeStudioDraft())
    #expect(!model.isDirty)
    #expect(!model.canUndo)
    #expect(model.state == .editing)
}

@Test @MainActor
func discardedDraftIgnoresAStaleImageSelectionFailure() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioStaleImageFailure-\(UUID().uuidString)")
    let paletteGate = ThemeStudioOperationGate<HabitatThemePalette>()
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations(paletteGate: paletteGate)
    )
    let selectedURL = root.appending(path: "pending.jpg")

    let selection = Task { try await model.selectImage(selectedURL) }
    await paletteGate.waitUntilStarted()
    model.discardDraft()
    paletteGate.fail(TestThemeStudioOperationError.expectedFailure)
    try await selection.value

    #expect(model.imageValidationMessage == nil)
    #expect(model.state == .editing)
}

@Test @MainActor
func pendingImageSelectionBlocksPersistenceWithoutDiscardingTheSelection() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioPendingImage-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceImageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)
    let replacementImageURL = try #require(HabitatThemeDescriptor.builtIn.dropFirst().first?.backgroundURL)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let installed = try ThemePackageBuilder(
        workingRoot: root.appending(path: "InitialWork")
    ).buildAndInstall(
        highPrecisionThemeRequest(sourceImageURL: sourceImageURL),
        libraryRoot: library
    )
    let paletteGate = ThemeStudioOperationGate<HabitatThemePalette>()
    let installGate = ThemeStudioOperationGate<String>()
    let exportGate = ThemeStudioOperationGate<Void>()
    let model = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "EditWork"),
        editing: installed,
        operations: controlledThemeStudioOperations(
            paletteGate: paletteGate,
            installGate: installGate,
            exportGate: exportGate
        )
    )

    let selection = Task { try await model.selectImage(replacementImageURL) }
    await paletteGate.waitUntilStarted()
    #expect(model.isSelectingImage)

    let save = Task { await model.saveLocally() }
    let export = Task { await model.export(to: root.appending(path: "blocked.habitat-pack")) }
    for _ in 0..<100 {
        await Task.yield()
    }

    #expect(installGate.invocationCount == 0)
    #expect(exportGate.invocationCount == 0)
    #expect(model.isSelectingImage)

    if installGate.invocationCount > 0 {
        installGate.succeed(installed.id)
    }
    if exportGate.invocationCount > 0 {
        exportGate.succeed(())
    }
    paletteGate.succeed(testThemePalette)
    try await selection.value
    await save.value
    await export.value

    #expect(!model.isSelectingImage)
    #expect(model.sourceImageURL == replacementImageURL)
    #expect(model.palette == testThemePalette)
    #expect(model.isDirty)
}

@Test @MainActor
func closingDuringPendingImageSelectionInvalidatesItsResult() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioCloseSelection-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let imageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)
    let paletteGate = ThemeStudioOperationGate<HabitatThemePalette>()
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations(paletteGate: paletteGate)
    )

    let selection = Task { try await model.selectImage(imageURL) }
    await paletteGate.waitUntilStarted()

    #expect(model.requestClose())
    #expect(!model.isSelectingImage)

    paletteGate.succeed(testThemePalette)
    try await selection.value

    #expect(model.sourceImageURL == nil)
    #expect(model.palette == nil)
    #expect(!model.isDirty)
}

@Test @MainActor
func staleImageSelectionCompletionCannotUnlockTheCurrentSelection() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioSelectionGeneration-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let firstImageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)
    let secondImageURL = try #require(HabitatThemeDescriptor.builtIn.dropFirst().first?.backgroundURL)
    let paletteGate = ThemeStudioOperationGate<HabitatThemePalette>()
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations(paletteGate: paletteGate)
    )

    let firstSelection = Task { try await model.selectImage(firstImageURL) }
    await paletteGate.waitUntilStarted()
    let secondSelection = Task { try await model.selectImage(secondImageURL) }
    await paletteGate.waitUntilStarted(2)

    paletteGate.succeed(testThemePalette)
    try await firstSelection.value

    #expect(model.isSelectingImage)
    #expect(model.sourceImageURL == nil)

    paletteGate.succeed(testThemePalette)
    try await secondSelection.value

    #expect(!model.isSelectingImage)
    #expect(model.sourceImageURL == secondImageURL)
}

@Test @MainActor
func installedThemePreservesHighPrecisionFocusThroughUnrelatedSave() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioFocusRoundTrip-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceImageURL = try #require(HabitatThemeDescriptor.builtIn.first?.backgroundURL)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let request = highPrecisionThemeRequest(sourceImageURL: sourceImageURL)
    let installed = try ThemePackageBuilder(
        workingRoot: root.appending(path: "InitialWork")
    ).buildAndInstall(request, libraryRoot: library)
    let model = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "EditWork"),
        editing: installed
    )

    #expect(model.artFocus == request.artFocus)
    #expect(model.homeArtFocus == request.homeArtFocus)
    #expect(model.taskArtFocus == request.taskArtFocus)
    #expect(!model.isDirty)

    model.author = "Updated Author"
    await model.saveLocally()
    guard case .replacementRequired = model.state else {
        Issue.record("Expected replacement confirmation, got \(model.state)")
        return
    }
    await model.replaceExistingTheme()

    let saved = try #require(InstalledPackageLibrary(
        root: library,
        runtimeVersion: "1.0.0"
    ).currentPackages().first?.manifest.theme)
    #expect(saved.artFocus == request.artFocus)
    #expect(saved.homeArtFocus == request.homeArtFocus)
    #expect(saved.taskArtFocus == request.taskArtFocus)
}

@Test @MainActor
func saveIsSingleFlightAndNewerEditsRemainUnsaved() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioSingleSave-\(UUID().uuidString)")
    let installGate = ThemeStudioOperationGate<String>()
    let exportGate = ThemeStudioOperationGate<Void>()
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations(
            installGate: installGate,
            exportGate: exportGate
        )
    )
    try await prepareValidControlledDraft(model, imageURL: root.appending(path: "source.jpg"))

    let save = Task { await model.saveLocally() }
    await installGate.waitUntilStarted()
    let savedName = model.name
    model.name = "Edited while saving"
    #expect(model.state == .saving)
    model.undo()
    #expect(model.state == .saving)
    model.redo()
    #expect(model.state == .saving)

    #expect(!model.requestClose())
    #expect(!model.showsDiscardConfirmation)
    let draftBeforeBlockedDiscard = model.draft
    model.discardDraft()
    #expect(model.draft == draftBeforeBlockedDiscard)

    await model.saveLocally()
    await model.export(to: root.appending(path: "ignored.habitat-pack"))
    #expect(installGate.invocationCount == 1)
    #expect(exportGate.invocationCount == 0)

    installGate.succeed("local.theme.concurrent-save")
    await save.value

    #expect(model.state == .editing)
    #expect(model.isDirty)
    #expect(model.canUndo)
    model.undo()
    #expect(model.name == savedName)
    #expect(!model.isDirty)
}

@Test @MainActor
func exportIsSingleFlightAndReleasesTheModelAfterCompletion() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioSingleExport-\(UUID().uuidString)")
    let installGate = ThemeStudioOperationGate<String>()
    let exportGate = ThemeStudioOperationGate<Void>()
    let model = ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work"),
        operations: controlledThemeStudioOperations(
            installGate: installGate,
            exportGate: exportGate
        )
    )
    try await prepareValidControlledDraft(model, imageURL: root.appending(path: "source.jpg"))

    let export = Task { await model.export(to: root.appending(path: "theme.habitat-pack")) }
    await exportGate.waitUntilStarted()
    model.author = "Edited while exporting"
    await model.saveLocally()
    #expect(exportGate.invocationCount == 1)
    #expect(installGate.invocationCount == 0)

    exportGate.succeed(())
    await export.value
    #expect(model.state == .editing)
    #expect(model.isDirty)

    let save = Task { await model.saveLocally() }
    await installGate.waitUntilStarted()
    installGate.succeed("local.theme.after-export")
    await save.value
    #expect(model.state == .saved("local.theme.after-export"))
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
    creator.setHomeArtFocus(x: 0.19, y: 0.61)
    creator.setTaskArtFocus(x: 0.29, y: 0.58)
    creator.setHomeArtScale(1.13)
    creator.setTaskArtScale(1.05)
    creator.setTaskSidebarOpacity(0.77)
    creator.setTaskHeaderOpacity(0.70)
    creator.setHomeContentOpacity(0.56)
    creator.setTaskContentOpacity(0.73)
    creator.setHomeContentWidth(0.58)
    creator.setVignetteStrength(0.42)
    try await creator.selectImage(sourceImageURL)
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
    #expect(editor.homeArtFocus == HabitatThemeFocalPoint(x: 0.19, y: 0.61))
    #expect(editor.taskArtFocus == HabitatThemeFocalPoint(x: 0.29, y: 0.58))
    #expect(editor.homeArtScale == 1.13)
    #expect(editor.taskArtScale == 1.05)
    #expect(editor.taskSidebarOpacity == 0.77)
    #expect(editor.taskHeaderOpacity == 0.70)
    #expect(editor.homeContentOpacity == 0.56)
    #expect(editor.taskContentOpacity == 0.73)
    #expect(editor.homeContentWidth == 0.58)
    #expect(editor.vignetteStrength == 0.42)
    #expect(editor.pairedPetID == "test-pet")
    #expect(!editor.isDirty)
    #expect(appModel.makeThemeStudioModel(editingThemeID: "workbench") == nil)

    let installed = try #require(appModel.installedPackages.first)
    #expect(HabitatAppModel.isThemeStudioEditableManifest(
        installed.manifest,
        packageID: installed.id
    ))
    let manifestURL = installed.url.appending(path: "habitat.json")
    let manifestData = try Data(contentsOf: manifestURL)
    var manifestObject = try #require(
        JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
    )
    manifestObject["id"] = "vendor.external-theme"
    let externalManifest = try JSONDecoder().decode(
        HabitatManifest.self,
        from: JSONSerialization.data(withJSONObject: manifestObject)
    )
    #expect(!HabitatAppModel.isThemeStudioEditableManifest(
        externalManifest,
        packageID: externalManifest.id
    ))

    manifestObject["id"] = installed.id
    manifestObject["pets"] = [[
        "id": "bundled-pet",
        "path": "Pets/bundled-pet",
        "rendering": "smooth",
        "scale": 1.0,
    ]]
    let compositeManifest = try JSONDecoder().decode(
        HabitatManifest.self,
        from: JSONSerialization.data(withJSONObject: manifestObject)
    )
    #expect(!HabitatAppModel.isThemeStudioEditableManifest(
        compositeManifest,
        packageID: installed.id
    ))
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
    try await original.selectImage(imageURL)
    await original.saveLocally()
    let themeID = try #require(original.state.savedID)

    let replacement = ThemeStudioModel(
        libraryRoot: library,
        workingRoot: root.appending(path: "ReplacementWork")
    )
    replacement.name = "Slug Collision"
    replacement.author = "Replacement Author"
    try await replacement.selectImage(imageURL)

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

private enum TestThemeStudioOperationError: Error {
    case expectedFailure
    case unexpectedOperation
}

private let testThemePalette = HabitatThemePalette(
    surface: "#101820",
    panel: "#182633",
    panelAlt: "#24384A",
    text: "#F4FAFF",
    mutedText: "#AAB8C4",
    accent: "#16C6D9",
    secondary: "#41D17D",
    highlight: "#85F4FF",
    attention: "#FFB547",
    error: "#FF5C70"
)

private func highPrecisionThemeRequest(sourceImageURL: URL) -> ThemePackageRequest {
    ThemePackageRequest(
        name: "High Precision Theme",
        author: "Original Author",
        sourceImageURL: sourceImageURL,
        palette: testThemePalette,
        category: .custom,
        styleFamily: .retroMessenger,
        artFocus: HabitatThemeFocalPoint(x: 0.3746, y: 0.6254),
        safeSide: .trailing,
        backgroundStrength: 0.51,
        panelOpacity: 0.79,
        blurRadius: 13,
        density: .compact,
        homeMode: .framed,
        taskMode: .banner,
        chromeMaterial: .glass,
        homeStrength: 0.62,
        taskStrength: 0.28,
        sidebarOpacity: 0.74,
        headerOpacity: 0.69,
        composerOpacity: 0.91,
        homeArtFocus: HabitatThemeFocalPoint(x: 0.1846, y: 0.6246),
        taskArtFocus: HabitatThemeFocalPoint(x: 0.2746, y: 0.5746),
        homeArtScale: 1.13,
        taskArtScale: 1.05,
        taskSidebarOpacity: 0.77,
        taskHeaderOpacity: 0.70,
        homeContentOpacity: 0.56,
        taskContentOpacity: 0.73,
        homeContentWidth: 0.58,
        vignetteStrength: 0.42
    )
}

private func controlledThemeStudioOperations(
    paletteGate: ThemeStudioOperationGate<HabitatThemePalette>? = nil,
    installGate: ThemeStudioOperationGate<String>? = nil,
    exportGate: ThemeStudioOperationGate<Void>? = nil
) -> ThemeStudioOperations {
    ThemeStudioOperations(
        suggestPalette: { _, _ in
            if let paletteGate {
                return try await paletteGate.run()
            }
            return testThemePalette
        },
        install: { _, _, _, _ in
            guard let installGate else { throw TestThemeStudioOperationError.unexpectedOperation }
            return try await installGate.run()
        },
        export: { _, _, _ in
            guard let exportGate else { throw TestThemeStudioOperationError.unexpectedOperation }
            return try await exportGate.run()
        }
    )
}

@MainActor
private func prepareValidControlledDraft(
    _ model: ThemeStudioModel,
    imageURL: URL
) async throws {
    model.name = "Controlled Theme"
    model.author = "Local Artist"
    try await model.selectImage(imageURL)
}

private final class ThemeStudioOperationGate<Output: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [CheckedContinuation<Output, any Error>] = []
    private var startedWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var startedCount = 0

    var invocationCount: Int {
        lock.withLock { startedCount }
    }

    func run() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let waiters = lock.withLock {
                pending.append(continuation)
                startedCount += 1
                let ready = startedWaiters.filter { $0.count <= startedCount }
                startedWaiters.removeAll { $0.count <= startedCount }
                return ready.map(\.continuation)
            }
            waiters.forEach { $0.resume() }
        }
    }

    func waitUntilStarted(_ count: Int = 1) async {
        await withCheckedContinuation { continuation in
            let alreadyStarted = lock.withLock {
                if startedCount >= count {
                    return true
                }
                startedWaiters.append((count, continuation))
                return false
            }
            if alreadyStarted {
                continuation.resume()
            }
        }
    }

    func succeed(_ output: Output) {
        finish(with: .success(output))
    }

    func fail(_ error: any Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<Output, any Error>) {
        let continuation = lock.withLock { pending.isEmpty ? nil : pending.removeFirst() }
        continuation?.resume(with: result)
    }
}

private extension ThemeStudioState {
    var savedID: String? {
        guard case let .saved(id) = self else { return nil }
        return id
    }
}
