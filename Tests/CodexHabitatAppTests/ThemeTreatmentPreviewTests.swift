import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func themeTreatmentPreviewUsesOpaqueGlassWhenTransparencyIsReduced() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("@Environment(\\.accessibilityReduceTransparency)"))
    #expect(source.contains("if reduceTransparency"))
}

@Test
func fourPrototypeThemesResolveDistinctCompletePreviewTreatments() throws {
    let ids = ["workbench", "retro-messenger", "arcade-signal", "quiet-garden"]
    let themes = try ids.map { id in
        try #require(HabitatThemeDescriptor.builtIn.first { $0.id == id })
    }
    let models = themes.map(ThemeTreatmentPreviewModel.init(theme:))

    #expect(Set(models.map(\.treatmentSignature)).count == 4)

    let workbench = models[0]
    #expect(workbench.homeMode == .immersive)
    #expect(workbench.taskMode == .ambient)
    #expect(workbench.chromeMaterial == .tinted)
    #expect(workbench.safeSide == .leading)
    #expect(workbench.homeStrength == 0.85)
    #expect(workbench.taskStrength == 0.56)
    #expect(workbench.sidebarOpacity == 0.54)
    #expect(workbench.headerOpacity == 0.20)
    #expect(workbench.composerOpacity == 0.84)
    #expect(workbench.homeArtFocus == HabitatThemeFocalPoint(x: 0.82, y: 0.50))
    #expect(workbench.taskArtFocus == HabitatThemeFocalPoint(x: 0.78, y: 0.48))
    #expect(workbench.homeArtScale == 1.10)
    #expect(workbench.taskArtScale == 1.04)
    #expect(workbench.taskSidebarOpacity == 0.74)
    #expect(workbench.taskHeaderOpacity == 0.64)
    #expect(workbench.homeContentOpacity == 0.54)
    #expect(workbench.taskContentOpacity == 0.68)
    #expect(workbench.vignetteStrength == 0.46)
    #expect(workbench.density == .comfortable)

    let retroMessenger = models[1]
    #expect(retroMessenger.homeMode == .framed)
    #expect(retroMessenger.safeSide == .trailing)

    let quietGarden = models[3]
    #expect(quietGarden.surfaceHex == "#F4FAF2")
    #expect(quietGarden.panelHex == "#F9FFF8")
    #expect(quietGarden.panelAltHex == "#DCEFD9")
    #expect(quietGarden.textHex == "#193525")
}

@Test
func previewModelUsesResolvedCompatibilityDefaults() {
    let appearance = HabitatThemeAppearance(
        category: .custom,
        styleFamily: .cozyWorld,
        background: "background.jpg",
        artFocus: HabitatThemeFocalPoint(x: 0.25, y: 0.75),
        safeSide: .none,
        backgroundStrength: 0.50,
        panelOpacity: 0.80,
        blurRadius: 12,
        density: .compact
    )
    let model = ThemeTreatmentPreviewModel(
        appearance: appearance,
        surfaceHex: "#101820",
        panelHex: "#182633",
        panelAltHex: "#24384A",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9"
    )

    #expect(model.homeMode == .quiet)
    #expect(model.taskMode == .ambient)
    #expect(model.chromeMaterial == .tinted)
    #expect(model.homeStrength == 0.50)
    #expect(model.taskStrength == 0.23)
    #expect(model.sidebarOpacity == 0.80)
    #expect(model.headerOpacity == 0.80)
    #expect(model.composerOpacity == 0.80)
    #expect(model.homeArtFocus == appearance.resolvedHomeArtFocus)
    #expect(model.taskArtFocus == appearance.resolvedTaskArtFocus)
    #expect(model.homeArtScale == appearance.resolvedHomeArtScale)
    #expect(model.taskArtScale == appearance.resolvedTaskArtScale)
    #expect(model.taskSidebarOpacity == appearance.resolvedTaskSidebarOpacity)
    #expect(model.taskHeaderOpacity == appearance.resolvedTaskHeaderOpacity)
    #expect(model.homeContentOpacity == appearance.resolvedHomeContentOpacity)
    #expect(model.taskContentOpacity == appearance.resolvedTaskContentOpacity)
    #expect(model.vignetteStrength == appearance.resolvedVignetteStrength)
}

@Test
func previewSignatureChangesForEveryRouteCompositionField() {
    let base = previewSceneAppearance()
    let appearances = [
        base,
        previewSceneAppearance(homeArtFocus: HabitatThemeFocalPoint(x: 0.31, y: 0.42)),
        previewSceneAppearance(taskArtFocus: HabitatThemeFocalPoint(x: 0.69, y: 0.58)),
        previewSceneAppearance(homeArtScale: 1.17),
        previewSceneAppearance(taskArtScale: 1.11),
        previewSceneAppearance(taskSidebarOpacity: 0.79),
        previewSceneAppearance(taskHeaderOpacity: 0.73),
        previewSceneAppearance(homeContentOpacity: 0.61),
        previewSceneAppearance(taskContentOpacity: 0.77),
        previewSceneAppearance(vignetteStrength: 0.51),
    ]
    let signatures = appearances.map {
        ThemeTreatmentPreviewModel(
            appearance: $0,
            surfaceHex: "#101820",
            panelHex: "#182633",
            panelAltHex: "#24384A",
            textHex: "#F4FAFF",
            accentHex: "#16C6D9"
        ).treatmentSignature
    }

    #expect(Set(signatures).count == appearances.count)
}

@Test
func previewIgnoresLegacyHomeContentWidth() {
    let narrow = ThemeTreatmentPreviewModel(
        appearance: previewSceneAppearance(homeContentWidth: 0.46),
        surfaceHex: "#101820",
        panelHex: "#182633",
        panelAltHex: "#24384A",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9"
    )
    let wide = ThemeTreatmentPreviewModel(
        appearance: previewSceneAppearance(homeContentWidth: 0.68),
        surfaceHex: "#101820",
        panelHex: "#182633",
        panelAltHex: "#24384A",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9"
    )

    #expect(narrow.treatmentSignature == wide.treatmentSignature)
}

@Test
func previewModelUsesTheSharedArtworkCropPlan() {
    let appearance = previewSceneAppearance(
        homeArtFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.25),
        taskArtFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.75),
        homeArtScale: 1.08,
        taskArtScale: 1.08
    )
    let model = ThemeTreatmentPreviewModel(
        appearance: appearance,
        surfaceHex: "#101820",
        panelHex: "#182633",
        panelAltHex: "#24384A",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9"
    )

    #expect(model.homeArtworkCrop == HabitatThemeArtworkCrop(
        focus: HabitatThemeFocalPoint(x: 0.5, y: 0.25),
        scale: 1.08
    ))
    #expect(model.taskArtworkCrop == HabitatThemeArtworkCrop(
        focus: HabitatThemeFocalPoint(x: 0.5, y: 0.75),
        scale: 1.08
    ))
    #expect(abs(model.homeArtworkCrop.drawRect(
        imageSize: HabitatThemeArtworkCrop.Size(width: 1_600, height: 1_000),
        viewportSize: HabitatThemeArtworkCrop.Size(width: 1_180, height: 820)
    ).y - -16.4) < 0.001)
    #expect(abs(model.taskArtworkCrop.drawRect(
        imageSize: HabitatThemeArtworkCrop.Size(width: 1_600, height: 1_000),
        viewportSize: HabitatThemeArtworkCrop.Size(width: 1_180, height: 820)
    ).y - -49.2) < 0.001)
}

@Test
func previewRecipesAreDistinctAcrossHostOwnedStyleFamilies() {
    let recipes = HabitatThemeStyleFamily.allCases.map(\.surfaceRecipe)

    #expect(recipes.count == 9)
    #expect(Set(recipes.map(\.signature)).count == recipes.count)
    #expect(HabitatThemeStyleFamily.classicDesktop.surfaceRecipe.composerRadius == 0)
    #expect(HabitatThemeStyleFamily.retroMessenger.surfaceRecipe.headerEdgeWidth == 1)
    #expect(HabitatThemeStyleFamily.greenChat.surfaceRecipe.headerEdgeWidth == 4)
    #expect(HabitatThemeStyleFamily.animeEnergy.surfaceRecipe.headerEdgeWidth == 3)
}

@Test
func previewModelUsesTheSharedSurfaceRecipe() {
    for theme in HabitatThemeDescriptor.builtIn {
        let model = ThemeTreatmentPreviewModel(theme: theme)

        #expect(model.surfaceRecipe == theme.appearance.styleFamily.surfaceRecipe)
    }
}

@Test
func previewChromeSoftnessTracksBoundedBlur() {
    let sharp = ThemeTreatmentPreviewModel(
        appearance: previewSceneAppearance(blurRadius: 0),
        surfaceHex: "#101820",
        panelHex: "#182633",
        panelAltHex: "#24384A",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9"
    )
    let soft = ThemeTreatmentPreviewModel(
        appearance: previewSceneAppearance(blurRadius: 24),
        surfaceHex: "#101820",
        panelHex: "#182633",
        panelAltHex: "#24384A",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9"
    )

    #expect(sharp.chromeSoftness == 0)
    #expect(soft.chromeSoftness == 1)
}

@Test
func previewRouteMasksAndSelectedRecipeMetricMatchTheCompilerContract() throws {
    #expect(ThemeTreatmentPreviewSceneMetrics.bannerArtworkFraction == 0.52)
    #expect(ThemeTreatmentPreviewSceneMetrics.frameMatteThickness == 6)

    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift"
        ),
        encoding: .utf8
    )
    #expect(source.contains("recipe.selectedEdgeWidth"))
    #expect(source.contains("ThemeTreatmentPreviewSceneMetrics.bannerArtworkFraction"))
    #expect(source.contains("artworkLayers(in: size)"))
    #expect(!source.contains("artworkLayers(in: artworkSize)"))
    #expect(source.contains("ThemeTreatmentPreviewSceneMetrics.frameMatteThickness"))
    #expect(source.contains("ThemeTreatmentPreviewSceneMetrics.homeContentFraction"))
    #expect(source.contains("artworkCrop.drawRect"))
    #expect(source.contains("model.surfaceRecipe"))
    #expect(!source.contains("struct ThemeTreatmentPreviewRecipe"))
    #expect(!source.contains("recipe.sidebarFraction"))
    #expect(!source.contains("recipe.stageEdgeWidth"))
    #expect(!source.contains("recipe.railCount"))
    #expect(!source.contains("model.homeContentWidth"))
    #expect(!source.contains("* 0.26"))
}

@Test
func previewRendersEverySharedSurfaceRecipeDimension() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: repositoryRoot.appending(
            path: "Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift"
        ),
        encoding: .utf8
    )

    for field in [
        "recipe.materialStyle",
        "recipe.headerEdgeWidth",
        "recipe.headerLineStyle",
        "recipe.headerInsetDepth",
        "recipe.actionRadius",
        "recipe.actionEdgeWidth",
        "recipe.actionLineStyle",
        "recipe.readingRadius",
        "recipe.readingEdgeWidth",
        "recipe.readingLineStyle",
        "recipe.composerRadius",
        "recipe.composerEdgeWidth",
        "recipe.composerShadowRadius",
        "recipe.selectedEdgeWidth",
        "recipe.focusStyle",
        "recipe.hoverEmphasisPercent",
        "recipe.focusEmphasisPercent",
    ] {
        #expect(source.contains(field), "preview ignores \(field)")
    }
    #expect(source.contains("model.density"))
}

private func previewSceneAppearance(
    blurRadius: Double = 10,
    homeArtFocus: HabitatThemeFocalPoint = HabitatThemeFocalPoint(x: 0.25, y: 0.45),
    taskArtFocus: HabitatThemeFocalPoint = HabitatThemeFocalPoint(x: 0.75, y: 0.55),
    homeArtScale: Double = 1.08,
    taskArtScale: Double = 1.03,
    taskSidebarOpacity: Double = 0.72,
    taskHeaderOpacity: Double = 0.66,
    homeContentOpacity: Double = 0.56,
    taskContentOpacity: Double = 0.70,
    homeContentWidth: Double = 0.54,
    vignetteStrength: Double = 0.36
) -> HabitatThemeAppearance {
    HabitatThemeAppearance(
        category: .custom,
        styleFamily: .gameCinematic,
        background: "background.jpg",
        artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
        safeSide: .leading,
        backgroundStrength: 0.42,
        panelOpacity: 0.88,
        blurRadius: blurRadius,
        density: .comfortable,
        homeMode: .immersive,
        taskMode: .ambient,
        chromeMaterial: .tinted,
        homeStrength: 0.72,
        taskStrength: 0.38,
        sidebarOpacity: 0.58,
        headerOpacity: 0.22,
        composerOpacity: 0.94,
        homeArtFocus: homeArtFocus,
        taskArtFocus: taskArtFocus,
        homeArtScale: homeArtScale,
        taskArtScale: taskArtScale,
        taskSidebarOpacity: taskSidebarOpacity,
        taskHeaderOpacity: taskHeaderOpacity,
        homeContentOpacity: homeContentOpacity,
        taskContentOpacity: taskContentOpacity,
        homeContentWidth: homeContentWidth,
        vignetteStrength: vignetteStrength
    )
}
