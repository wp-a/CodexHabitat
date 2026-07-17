import Foundation
import Testing
@testable import CodexHabitatApp

@Test
func codexThemeShareStringUsesTheVerifiedLocalV1Shape() throws {
    let theme = HabitatThemeDescriptor.builtIn[1]

    let share = CodexThemeShareString.make(theme: theme, variant: .dark)

    #expect(share.hasPrefix("codex-theme-v1:"))
    let payload = Data(share.dropFirst("codex-theme-v1:".count).utf8)
    let object = try #require(
        JSONSerialization.jsonObject(with: payload) as? [String: Any]
    )
    #expect(object["codeThemeId"] as? String == "codex")
    #expect(object["variant"] as? String == "dark")
    let colors = try #require(object["theme"] as? [String: Any])
    #expect(colors["surface"] as? String == theme.surfaceHex)
    #expect(colors["ink"] as? String == theme.textHex)
    #expect(colors["accent"] as? String == theme.accentHex)
    #expect(colors["opaqueWindows"] as? Bool == true)
    #expect(colors["contrast"] as? Int == 50)
    #expect(!share.contains("http://"))
    #expect(!share.contains("https://"))
}

@Test
func suggestedVariantFollowsThemeSurfaceLuminance() {
    #expect(CodexThemeShareString.suggestedVariant(
        for: HabitatThemeDescriptor.builtIn[0]
    ) == .light)
    #expect(CodexThemeShareString.suggestedVariant(
        for: HabitatThemeDescriptor.builtIn[1]
    ) == .dark)
}
