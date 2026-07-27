import Testing
@testable import HabitatCore

@Test
func surfaceRecipesAreDistinctAcrossEveryHostOwnedStyleFamily() {
    let recipes = HabitatThemeStyleFamily.allCases.map(\.surfaceRecipe)

    #expect(recipes.count == 9)
    #expect(Set(recipes.map(\.signature)).count == recipes.count)
    #expect(Set(recipes.map(\.materialStyle)).count == recipes.count)
}

@Test
func surfaceRecipesStayInsideTheNonGeometricContract() {
    let forbiddenGeometryFields = Set([
        "sidebarFraction",
        "sidebarWidth",
        "stageOffset",
        "homeContentWidth",
        "composerOffset",
    ])

    for recipe in HabitatThemeStyleFamily.allCases.map(\.surfaceRecipe) {
        let storedFields = Set(Mirror(reflecting: recipe).children.compactMap(\.label))

        #expect(storedFields.isDisjoint(with: forbiddenGeometryFields))
        #expect((0...4).contains(recipe.headerEdgeWidth))
        #expect((0...8).contains(recipe.headerInsetDepth))
        #expect((0...12).contains(recipe.actionRadius))
        #expect((0...4).contains(recipe.actionEdgeWidth))
        #expect((0...12).contains(recipe.readingRadius))
        #expect((0...4).contains(recipe.readingEdgeWidth))
        #expect((0...12).contains(recipe.composerRadius))
        #expect((0...4).contains(recipe.composerEdgeWidth))
        #expect((0...8).contains(recipe.composerShadowRadius))
        #expect((0...12).contains(recipe.selectedRadius))
        #expect((1...4).contains(recipe.selectedEdgeWidth))
        #expect((0...8).contains(recipe.selectedShadowRadius))
        #expect((0...100).contains(recipe.hoverEmphasisPercent))
        #expect((0...100).contains(recipe.focusEmphasisPercent))
        #expect((0...16).contains(recipe.innerHighlightPercent))
    }
}

@Test
func surfaceRecipesPreserveTheEstablishedFamilyIdentities() {
    let classic = HabitatThemeStyleFamily.classicDesktop.surfaceRecipe
    #expect(classic.actionRadius == 0)
    #expect(classic.readingRadius == 0)
    #expect(classic.composerRadius == 0)
    #expect(classic.actionLineStyle == .raised)
    #expect(classic.focusStyle == .dotted)

    let cozy = HabitatThemeStyleFamily.cozyWorld.surfaceRecipe
    #expect(cozy.actionRadius == 8)
    #expect(cozy.readingRadius == 8)
    #expect(cozy.composerRadius == 8)
    #expect(cozy.actionLineStyle == .solid)

    let anime = HabitatThemeStyleFamily.animeEnergy.surfaceRecipe
    #expect(anime.headerEdgeWidth == 3)
    #expect(anime.actionLineStyle == .dashed)
    #expect(anime.focusStyle == .solid)
}
