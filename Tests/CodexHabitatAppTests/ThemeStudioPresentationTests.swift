import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func studioLayoutKeepsTheCanvasPrimaryAndTheInspectorReadable() {
    #expect(ThemeStudioLayoutMetrics.inspectorMinimumWidth == 352)
    #expect(ThemeStudioLayoutMetrics.inspectorIdealWidth == 368)
    #expect(ThemeStudioLayoutMetrics.inspectorMaximumWidth == 388)
    #expect(ThemeStudioLayoutMetrics.toolbarHeight == 48)
}

@Test
func studioInspectorUsesThreeProgressiveGroupsWithoutDroppingControls() {
    #expect(ThemeStudioInspectorGroup.allCases == [.basic, .appearance, .advanced])
    #expect(ThemeStudioInspectorGroup.defaultExpanded == [.basic])
    #expect(
        Set(ThemeStudioInspectorGroup.allCases.flatMap(\.sections))
            == Set(ThemeStudioInspectorSection.allCases)
    )
}

@Test
func emptyStudioStillRendersTheHostShellAndPromptsForArtwork() {
    let presentation = ThemeStudioCanvasPresentation(draft: ThemeStudioDraft())

    #expect(presentation.rendersHostShell)
    #expect(presentation.showsArtworkPrompt)
    #expect(!presentation.allowsFocalEditing)
}

@Test
func completeStudioDraftKeepsTheShellAndEnablesFocalEditing() {
    var draft = ThemeStudioDraft()
    draft.sourceImageURL = URL(fileURLWithPath: "/tmp/original-theme.jpg")
    draft.palette = HabitatThemePalette(
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

    let presentation = ThemeStudioCanvasPresentation(draft: draft)
    #expect(presentation.rendersHostShell)
    #expect(!presentation.showsArtworkPrompt)
    #expect(presentation.allowsFocalEditing)
}

@Test
func emptyStudioUsesACompactArtworkToolWithoutAFallbackWatermark() throws {
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
    let promptStart = try #require(source.range(of: "private var emptyArtwork"))
    let previewModelStart = try #require(source.range(of: "private var previewModel"))
    let promptSource = source[promptStart.lowerBound..<previewModelStart.lowerBound]

    #expect(source.contains("showsFallbackSymbol: false"))
    #expect(promptSource.contains("Image(systemName: \"photo.badge.plus\")"))
    #expect(promptSource.contains(".help(L10n.text(\"Choose Image\"))"))
    #expect(!promptSource.contains("Label(L10n.text(\"Choose Image\"), systemImage:"))
}
