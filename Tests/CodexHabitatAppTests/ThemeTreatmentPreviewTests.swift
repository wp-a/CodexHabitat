import HabitatCore
import Testing
@testable import CodexHabitatApp

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
    #expect(workbench.homeStrength == 0.72)
    #expect(workbench.taskStrength == 0.30)
    #expect(workbench.sidebarOpacity == 0.92)
    #expect(workbench.headerOpacity == 0.66)
    #expect(workbench.composerOpacity == 0.90)
    #expect(workbench.density == .comfortable)
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
}
