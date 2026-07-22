import CoreGraphics
import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test @MainActor
func studioUndoRestoresPreviousTypedDraft() {
    let model = makeHistoryModel()
    let original = model.draft

    model.setHomeStrength(0.63)

    #expect(model.canUndo)
    #expect(!model.canRedo)
    #expect(model.draft != original)
    model.undo()
    #expect(model.draft == original)
    #expect(!model.canUndo)
    #expect(model.canRedo)
    model.redo()
    #expect(model.homeStrength == 0.63)
}

@Test @MainActor
func studioDraftIsAnEquatableSendableValueWithEveryEditableField() {
    let model = makeHistoryModel()
    let draft = model.draft

    requireSendable(draft)
    #expect(draft == model.draft)
    #expect(draft.name == model.name)
    #expect(draft.author == model.author)
    #expect(draft.sourceImageURL == model.sourceImageURL)
    #expect(draft.palette == model.palette)
    #expect(draft.category == model.category)
    #expect(draft.styleFamily == model.styleFamily)
    #expect(draft.artFocus == model.artFocus)
    #expect(draft.safeSide == model.safeSide)
    #expect(draft.backgroundStrength == model.backgroundStrength)
    #expect(draft.panelOpacity == model.panelOpacity)
    #expect(draft.blurRadius == model.blurRadius)
    #expect(draft.density == model.density)
    #expect(draft.homeMode == model.homeMode)
    #expect(draft.taskMode == model.taskMode)
    #expect(draft.chromeMaterial == model.chromeMaterial)
    #expect(draft.homeStrength == model.homeStrength)
    #expect(draft.taskStrength == model.taskStrength)
    #expect(draft.sidebarOpacity == model.sidebarOpacity)
    #expect(draft.headerOpacity == model.headerOpacity)
    #expect(draft.composerOpacity == model.composerOpacity)
    #expect(draft.homeArtFocus == model.homeArtFocus)
    #expect(draft.taskArtFocus == model.taskArtFocus)
    #expect(draft.homeArtScale == model.homeArtScale)
    #expect(draft.taskArtScale == model.taskArtScale)
    #expect(draft.taskSidebarOpacity == model.taskSidebarOpacity)
    #expect(draft.taskHeaderOpacity == model.taskHeaderOpacity)
    #expect(draft.homeContentOpacity == model.homeContentOpacity)
    #expect(draft.taskContentOpacity == model.taskContentOpacity)
    #expect(draft.homeContentWidth == model.homeContentWidth)
    #expect(draft.vignetteStrength == model.vignetteStrength)
    #expect(draft.pairedPetID == model.pairedPetID)
}

@Test @MainActor
func studioNoOpDoesNotCreateHistoryAndNewEditClearsRedo() {
    let model = makeHistoryModel()

    model.setHomeStrength(model.homeStrength)
    #expect(!model.canUndo)

    model.setHomeStrength(0.63)
    model.undo()
    #expect(model.canRedo)

    model.setTaskStrength(0.31)
    #expect(!model.canRedo)
    model.undo()
    #expect(model.taskStrength == 0.19)
}

@Test @MainActor
func studioHistoryRetainsOnlyFiftyMostRecentEdits() {
    let model = makeHistoryModel()

    for index in 0..<60 {
        model.name = "Theme \(index)"
    }
    for _ in 0..<50 {
        model.undo()
    }

    #expect(model.name == "Theme 9")
    #expect(!model.canUndo)
}

@Test @MainActor
func studioContinuousEditingCoalescesOneHundredUpdatesIntoOneUndo() {
    let model = makeHistoryModel()
    let original = model.homeArtFocus

    model.beginContinuousEdit()
    for index in 0..<100 {
        model.setHomeArtFocus(x: Double(index) / 99, y: 0.8)
    }
    model.endContinuousEdit()

    #expect(model.canUndo)
    model.undo()
    #expect(model.homeArtFocus == original)
    #expect(!model.canUndo)
}

@Test @MainActor
func studioUndoSafelyEndsAnUnfinishedContinuousEdit() {
    let model = makeHistoryModel()
    let original = model.homeStrength

    model.beginContinuousEdit()
    model.setHomeStrength(0.71)
    model.undo()

    #expect(model.homeStrength == original)
    #expect(!model.canUndo)
    #expect(model.canRedo)
}

@Test
func focalPointDragClampsToUnitCoordinates() {
    let rect = CGRect(x: 10, y: 20, width: 400, height: 300)

    #expect(ThemeFocalPointMapper.unitPoint(
        at: CGPoint(x: -20, y: 900),
        in: rect
    ) == HabitatThemeFocalPoint(x: 0, y: 1))
    #expect(ThemeFocalPointMapper.unitPoint(
        at: CGPoint(x: 410, y: 20),
        in: rect
    ) == HabitatThemeFocalPoint(x: 1, y: 0))
    #expect(ThemeFocalPointMapper.unitPoint(
        at: CGPoint(x: 210, y: 170),
        in: rect
    ) == HabitatThemeFocalPoint(x: 0.5, y: 0.5))
}

@Test @MainActor
func focalPointWritesMatchTheDisplayedWholePercentPrecision() {
    let rect = CGRect(x: 10, y: 20, width: 400, height: 300)
    let mapped = ThemeFocalPointMapper.unitPoint(
        at: CGPoint(
            x: rect.minX + rect.width * 0.3746,
            y: rect.minY + rect.height * 0.6254
        ),
        in: rect
    )
    let expected = HabitatThemeFocalPoint(x: 0.37, y: 0.63)

    #expect(mapped == expected)

    let model = makeHistoryModel()
    model.setArtFocus(x: 0.3746, y: 0.6254)
    model.setHomeArtFocus(x: 0.3746, y: 0.6254)
    model.setTaskArtFocus(x: 0.3746, y: 0.6254)

    #expect(model.artFocus == expected)
    #expect(model.homeArtFocus == expected)
    #expect(model.taskArtFocus == expected)
}

@Test
func focalPointMapperReturnsStableCenterForDegenerateOrNonfiniteInput() {
    let center = HabitatThemeFocalPoint(x: 0.5, y: 0.5)

    #expect(ThemeFocalPointMapper.unitPoint(
        at: .zero,
        in: CGRect(x: 0, y: 0, width: 0, height: 100)
    ) == center)
    #expect(ThemeFocalPointMapper.unitPoint(
        at: CGPoint(x: CGFloat.infinity, y: 10),
        in: CGRect(x: 0, y: 0, width: 100, height: 100)
    ) == center)
    #expect(ThemeFocalPointMapper.unitPoint(
        at: CGPoint(x: 10, y: 10),
        in: CGRect(x: 0, y: 0, width: CGFloat.nan, height: 100)
    ) == center)
}

@Test
func taskBannerDragUsesTheVisibleBandWithinTheFullCompilerViewport() {
    let canvas = CGRect(x: 0, y: 0, width: 1_000, height: 625)

    let artwork = ThemeFocalPointMapper.artworkRect(
        in: canvas,
        route: .task,
        taskMode: .banner
    )

    #expect(artwork == CGRect(x: 0, y: 0, width: 1_000, height: 325))
    #expect(ThemeFocalPointMapper.unitPoint(
        at: CGPoint(x: 500, y: 325),
        in: canvas
    ) == HabitatThemeFocalPoint(x: 0.5, y: 0.52))
}

@Test
func taskBannerCropUsesTheFullCompilerViewportBeforeClipping() {
    let viewport = HabitatThemeArtworkCrop.Size(width: 1_000, height: 625)
    let crop = HabitatThemeArtworkCrop(
        focus: HabitatThemeFocalPoint(x: 0.25, y: 0.75),
        scale: 1.20
    ).drawRect(
        imageSize: HabitatThemeArtworkCrop.Size(width: 1_600, height: 1_000),
        viewportSize: viewport
    )

    #expect(abs(crop.x - -50) < 0.001)
    #expect(abs(crop.y - -93.75) < 0.001)
    #expect(crop.width == 1_200)
    #expect(crop.height == 750)
}

@Test
func themeStudioSourceKeepsTheWideCanvasInspectorContract() throws {
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

    #expect(source.contains("HSplitView"))
    #expect(source.contains("minWidth: 560"))
    #expect(source.contains("minWidth: 320, idealWidth: 330, maxWidth: 340"))
    #expect(source.contains("idealWidth: 1_000"))
    #expect(source.contains("idealHeight: 700"))
    #expect(source.contains("aspectRatio(16.0 / 10.0"))
    #expect(source.components(separatedBy: "ScrollView {").count - 1 == 1)
    #expect(source.contains("interactiveDismissDisabled(model.isDirty || model.state == .saving)"))
}

@Test
func themeStudioSourceProvidesDirectManipulationAndSevenInspectorGroups() throws {
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

    #expect(source.contains("DragGesture(minimumDistance: 0"))
    #expect(source.contains(".coordinateSpace(name: \"theme-studio.artwork\")"))
    #expect(source.contains(".simultaneousGesture(focalDragGesture"))
    #expect(source.contains("focalDragGesture(in: canvasRect)"))
    #expect(source.contains("x: canvasRect.minX + focus.x * canvasRect.width"))
    #expect(source.contains("y: canvasRect.minY + focus.y * canvasRect.height"))
    #expect(source.contains("model.beginContinuousEdit()"))
    #expect(source.contains("model.endContinuousEdit()"))
    #expect(source.contains(".accessibilityAdjustableAction"))
    #expect(source.contains(".pickerStyle(.menu)"))
    for title in [
        "Metadata", "Artwork", "Palette", "Scene", "Material", "Pet Pairing", "Package",
    ] {
        #expect(source.contains("\"\(title)\""))
    }
}

@Test @MainActor
func studioValidationFailurePreservesDraftAndHistory() async {
    let model = makeHistoryModel()
    model.name = "Incomplete Theme"
    let draftBeforeSave = model.draft

    await model.saveLocally()

    #expect(model.draft == draftBeforeSave)
    #expect(model.canUndo)
    guard case .validationFailure = model.state else {
        Issue.record("Expected validation failure, got \(model.state)")
        return
    }
}

private func requireSendable<T: Sendable>(_ value: T) {}

@MainActor
private func makeHistoryModel() -> ThemeStudioModel {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "CodexHabitatThemeStudioHistory-\(UUID().uuidString)")
    return ThemeStudioModel(
        libraryRoot: root.appending(path: "Library"),
        workingRoot: root.appending(path: "Work")
    )
}
