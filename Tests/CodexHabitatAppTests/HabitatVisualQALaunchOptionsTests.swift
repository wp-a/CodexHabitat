import Testing
@testable import CodexHabitatApp

@Test
func visualQALaunchOptionsRequireAnExplicitGate() {
    let options = HabitatVisualQALaunchOptions(arguments: [
        "CodexHabitatApp",
        "--visual-qa-theme-filter", "anime",
        "--visual-qa-theme-studio",
        "--visual-qa-settings-width", "1040",
    ])

    #expect(options == .disabled)
}

@Test
func visualQALaunchOptionsParseOnlyBoundedViewState() {
    let options = HabitatVisualQALaunchOptions(arguments: [
        "CodexHabitatApp", "--visual-qa",
        "--visual-qa-theme-filter", "nostalgia",
        "--visual-qa-theme-studio",
        "--visual-qa-settings-width", "1040",
    ])

    #expect(options.themeFilter == .nostalgia)
    #expect(options.opensThemeStudio)
    #expect(options.settingsWidth == 1040)

    let invalid = HabitatVisualQALaunchOptions(arguments: [
        "CodexHabitatApp", "--visual-qa",
        "--visual-qa-theme-filter", "javascript",
        "--visual-qa-settings-width", "99999",
    ])
    #expect(invalid.themeFilter == .all)
    #expect(!invalid.opensThemeStudio)
    #expect(invalid.settingsWidth == 1_200)
}
