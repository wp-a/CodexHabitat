import Testing
@testable import CodexHabitatApp

@Test
func selectingThemeUpdatesPreviewWithoutRequestingApply() {
    var state = ThemeLibraryState()

    state.select("quiet-garden")

    #expect(state.previewedThemeID == "quiet-garden")
    #expect(state.pendingApplyThemeID == nil)
}

@Test
func favoriteOrderingIsStableAndDropsUnavailableOrDuplicateIDs() {
    let result = ThemeLibraryState.validFavorites(
        ["quiet-garden", "missing", "night-shift", "quiet-garden"],
        availableThemeIDs: ["night-shift", "quiet-garden"]
    )

    #expect(result == ["quiet-garden", "night-shift"])
}

@Test
func recentThemesAreDeduplicatedBoundedAndValidated() {
    let available = Set((0..<14).map { "theme-\($0)" })
    var recent = (0..<14).map { "theme-\($0)" } + ["missing", "theme-3"]

    recent = ThemeLibraryState.recordRecent(
        "theme-3",
        in: recent,
        availableThemeIDs: available
    )

    #expect(recent.count == 12)
    #expect(recent.first == "theme-3")
    #expect(recent.filter { $0 == "theme-3" }.count == 1)
    #expect(!recent.contains("missing"))
}

@Test
func invalidThemeCannotEnterRecentHistory() {
    #expect(ThemeLibraryState.recordRecent(
        "missing",
        in: ["workbench"],
        availableThemeIDs: ["workbench"]
    ) == ["workbench"])
}
