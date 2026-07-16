import Testing
@testable import CodexHabitatApp

@Test
func bundledThemeDescriptorsExposeValidatedTokensAndPreviews() throws {
    let themes = HabitatThemeDescriptor.builtIn

    #expect(themes.count == 4)
    #expect(themes.map(\.id) == ["workbench", "night-shift", "arcade-signal", "quiet-garden"])
    #expect(themes.allSatisfy { $0.previewURL != nil })
    #expect(themes.first(where: { $0.id == "workbench" })?.accentHex == "#0F8B8D")
    #expect(themes.first(where: { $0.id == "night-shift" })?.surfaceHex == "#171A1D")
    #expect(themes.first(where: { $0.id == "arcade-signal" })?.attentionHex == "#FFD23F")
    #expect(themes.first(where: { $0.id == "quiet-garden" })?.errorHex == "#C4455D")
}
