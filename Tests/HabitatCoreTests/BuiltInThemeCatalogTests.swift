import Testing
@testable import HabitatCore

@Test
func builtInCatalogHasTwelveStableGameThemes() {
    #expect(BuiltInThemeCatalog.all.map(\.id) == [
        "workbench", "night-shift", "arcade-signal", "quiet-garden",
        "retro-messenger", "green-chat-desk", "cyber-cafe", "candy-combo",
        "crimson-mecha", "win95-workbench", "gold-rush", "aqua-pulse",
    ])
    #expect(Set(BuiltInThemeCatalog.all.map(\.styleFamily)).count == 5)
}
