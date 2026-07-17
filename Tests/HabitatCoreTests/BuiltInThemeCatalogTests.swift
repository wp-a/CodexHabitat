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
