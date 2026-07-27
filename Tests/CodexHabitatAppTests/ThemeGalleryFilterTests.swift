import HabitatCore
import Testing
@testable import CodexHabitatApp

@Test
func galleryFiltersTwentyFourBuiltInsIntoProductCategories() {
    let themes = HabitatThemeDescriptor.builtIn

    #expect(ThemeGalleryQuery.filter(themes, by: .all, search: "").count == 24)
    #expect(ThemeGalleryQuery.filter(themes, by: .nostalgia, search: "").map(\.id) == [
        "retro-messenger", "cyber-cafe",
    ])
    #expect(ThemeGalleryQuery.filter(themes, by: .chat, search: "").map(\.id) == [
        "green-chat-desk",
    ])
    #expect(ThemeGalleryQuery.filter(themes, by: .anime, search: "").count == 3)
    #expect(ThemeGalleryQuery.filter(themes, by: .games, search: "").count == 11)
    #expect(ThemeGalleryQuery.filter(themes, by: .cozy, search: "").count == 4)
    #expect(ThemeGalleryQuery.filter(themes, by: .classic, search: "").map(\.id) == [
        "win95-workbench",
    ])
    #expect(ThemeGalleryQuery.filter(themes, by: .custom, search: "").isEmpty)

    let custom = HabitatThemeDescriptor(
        id: "local.theme.example",
        name: "Local Example",
        detail: "Local Artist",
        symbol: "paintpalette.fill",
        surfaceHex: "#101820",
        textHex: "#F4FAFF",
        accentHex: "#16C6D9",
        attentionHex: "#FFAA33",
        errorHex: "#F04455",
        previewURL: nil,
        category: .custom
    )
    #expect(ThemeGalleryQuery.filter(
        themes + [custom],
        by: .custom,
        search: ""
    ).map(\.id) == [custom.id])
}

@Test
func gallerySearchMatchesLocalizedThemeNameAndCategory() {
    let themes = HabitatThemeDescriptor.builtIn
    let localized: (String) -> String = { key in
        switch key {
        case "Grand Ocean Crew": "远洋伙伴"
        case HabitatThemeCategory.nostalgia.localizationKey: "怀旧"
        default: key
        }
    }

    #expect(ThemeGalleryQuery.filter(
        themes,
        by: .all,
        search: "远洋",
        localize: localized
    ).map(\.id) == ["grand-ocean-crew"])
    #expect(ThemeGalleryQuery.filter(
        themes,
        by: .all,
        search: "怀旧",
        localize: localized
    ).map(\.id) == ["retro-messenger", "cyber-cafe"])
}

@Test
func galleryComposesScopeCategoryAndSearchWithMetadataOrdering() {
    let themes = HabitatThemeDescriptor.builtIn

    let favorites = ThemeGalleryQuery.filter(
        themes,
        scope: .favorites,
        category: .all,
        search: "",
        favoriteThemeIDs: ["quiet-garden", "night-shift"],
        recentThemeIDs: []
    )
    #expect(favorites.map(\.id) == ["quiet-garden", "night-shift"])

    let recentGames = ThemeGalleryQuery.filter(
        themes,
        scope: .recent,
        category: .games,
        search: "",
        favoriteThemeIDs: [],
        recentThemeIDs: ["quiet-garden", "turbo-striker", "arcade-signal"]
    )
    #expect(recentGames.map(\.id) == ["turbo-striker", "arcade-signal"])
}

@Test
func galleryLayoutFillsItsPaneWithTwoOrThreeBalancedColumns() {
    #expect(ThemeGalleryLayout.columnCount(availableWidth: 520) == 2)
    #expect(ThemeGalleryLayout.columnCount(availableWidth: 690) == 3)
    #expect(ThemeGalleryLayout.columnCount(availableWidth: 1_200) == 3)
    #expect(ThemeGalleryLayout.cardWidth(availableWidth: 520) == 254)
    #expect(ThemeGalleryLayout.cardWidth(availableWidth: 690) == 222)
}
