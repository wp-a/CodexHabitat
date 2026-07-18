import Testing
@testable import HabitatCore

@Test
func builtInCatalogHasTwentyFourStableThemes() {
    #expect(BuiltInThemeCatalog.all.map(\.id) == [
        "workbench", "night-shift", "arcade-signal", "quiet-garden",
        "retro-messenger", "green-chat-desk", "cyber-cafe", "candy-combo",
        "crimson-mecha", "win95-workbench", "gold-rush", "aqua-pulse",
        "harvest-homestead", "solar-ki-arena", "moonlit-shinobi", "grand-ocean-crew",
        "elemental-companions", "walled-vanguard", "arcane-academy",
        "hero-training-campus", "nebula-vanguard", "spirit-lantern-town",
        "block-frontier", "turbo-striker",
    ])
    #expect(Set(BuiltInThemeCatalog.all.map(\.id)).count == 24)
    #expect(Set(BuiltInThemeCatalog.all.map(\.styleFamily)).count == 9)
    #expect(BuiltInThemeCatalog.all.allSatisfy { !$0.category.localizationKey.isEmpty })
    #expect(Set(HabitatThemeCategory.allCases.map(\.localizationKey)).count ==
        HabitatThemeCategory.allCases.count)
}

@Test
func fourPrototypeThemesHaveMateriallyDifferentRouteTreatments() throws {
    let identifiers = ["workbench", "retro-messenger", "arcade-signal", "quiet-garden"]
    let signatures = try identifiers.map { identifier in
        let definition = try #require(BuiltInThemeCatalog.definition(id: identifier))
        return treatmentSignature(definition.appearance(background: "background.jpg"))
    }

    #expect(Set(signatures).count == identifiers.count)
    #expect(BuiltInThemeCatalog.definition(id: "workbench")?.appearance(
        background: "background.jpg"
    ).resolvedHomeMode == .immersive)
    #expect(BuiltInThemeCatalog.definition(id: "retro-messenger")?.appearance(
        background: "background.jpg"
    ).resolvedChromeMaterial == .glass)
    #expect(BuiltInThemeCatalog.definition(id: "arcade-signal")?.appearance(
        background: "background.jpg"
    ).resolvedTaskMode == .banner)
    #expect(BuiltInThemeCatalog.definition(id: "quiet-garden")?.appearance(
        background: "background.jpg"
    ).resolvedTaskMode == .off)
    let quietGarden = try #require(BuiltInThemeCatalog.definition(id: "quiet-garden"))
    #expect(quietGarden.palette.surface == "#F4FAF2")
    #expect(quietGarden.palette.panel == "#F9FFF8")
    #expect(quietGarden.palette.panelAlt == "#DCEFD9")
    #expect(quietGarden.palette.text == "#193525")
}

private func treatmentSignature(_ appearance: HabitatThemeAppearance) -> String {
    [
        appearance.resolvedHomeMode.rawValue,
        appearance.resolvedTaskMode.rawValue,
        appearance.resolvedChromeMaterial.rawValue,
        appearance.density.rawValue,
        String(appearance.resolvedHomeStrength),
        String(appearance.resolvedTaskStrength),
        String(appearance.resolvedSidebarOpacity),
        String(appearance.resolvedHeaderOpacity),
        String(appearance.resolvedComposerOpacity),
    ].joined(separator: "|")
}
