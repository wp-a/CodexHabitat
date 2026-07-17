import Foundation
import Testing
@testable import CodexHabitatThemeBridge

@Test
func bundledProfileCompilesOnlyHostSelectorsApprovedTokensAndLocalBlobArt() throws {
    let store = try CompatibilityProfileStore.bundled()
    let profile = try #require(store.profile(forVersion: "26.707.91948"))
    let theme = BridgeTheme(
        tokens: BridgeThemeTokens(
            surface: "#171A1D",
            text: "#F1F5F6",
            accent: "#2DD4BF",
            attention: "#F59E0B",
            error: "#FB7185"
        ),
        artBlobURL: "blob:app://codex/habitat-art-1"
    )

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)

    #expect(css.contains("aside.app-shell-left-panel"))
    #expect(css.contains("main.main-surface"))
    #expect(css.contains(".composer-surface-chrome"))
    #expect(css.contains("#2DD4BF"))
    #expect(css.contains("blob:app://codex/habitat-art-1"))
    #expect(!css.contains("{{"))
    #expect(!css.contains("@import"))
    #expect(!css.contains("https://"))
    #expect(!css.contains("http://"))
}

@Test
func unknownCodexVersionsFailClosed() throws {
    let store = try CompatibilityProfileStore.bundled()

    #expect(store.profile(forVersion: "26.708.0") == nil)
    #expect(store.profile(forVersion: "999.0.0") == nil)
    #expect(store.profile(forVersion: "not-a-version") == nil)
}

@Test(arguments: [
    "https://example.com/art.png",
    "file:///tmp/art.png",
    "blob:https://example.com/art",
    "blob:app://codex/art?token=secret",
])
func remoteOrUnboundedArtURLsAreRejected(_ artURL: String) throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let theme = BridgeTheme(tokens: .workbench, artBlobURL: artURL)

    #expect(throws: ThemeCompilationError.invalidArtBlobURL) {
        try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    }
}

@Test
func themeJSONCannotProvideSelectorsCSSOrUnknownCommands() {
    let malicious = Data(#"""
    {
      "tokens": {
        "surface": "#FFFFFF", "text": "#111111", "accent": "#008080",
        "attention": "#D97706", "error": "#D64545"
      },
      "selectors": { "composer": "body *" },
      "css": "@import url(https://evil.example/x.css)",
      "command": "open -a Calculator"
    }
    """#.utf8)

    #expect(throws: ThemeCompilationError.unknownThemeField("selectors")) {
        try BridgeThemeDecoder().decode(malicious)
    }
}

@Test
func unsafeTemplateContentIsRejectedBeforeSubstitution() throws {
    #expect(throws: ThemeCompilationError.unsafeTemplate) {
        try ThemeCompiler(template: "@import url(https://evil.example/x.css);")
    }
}

@Test
func allFourBundledThemeIdentifiersResolveToApprovedTokenOnlyThemes() throws {
    for id in ["workbench", "night-shift", "arcade-signal", "quiet-garden"] {
        let theme = try #require(BridgeTheme.builtIn(id: id))
        #expect(theme.artBlobURL == nil)
        let artDataURL = try #require(theme.artDataURL)
        #expect(artDataURL.hasPrefix("data:image/png;base64,"))
        #expect(Data(base64Encoded: String(artDataURL.dropFirst("data:image/png;base64,".count))) != nil)
        let css = try ThemeCompiler.bundled().compile(
            theme: theme,
            profile: try #require(
                try CompatibilityProfileStore.bundled().profile(
                    forVersion: "26.707.91948"
                )
            )
        )
        #expect(css.contains("data:image/png;base64,"))
        #expect(css.contains("background-position: right bottom"))
    }
    #expect(BridgeTheme.builtIn(id: "unknown") == nil)
}

@Test
func untrustedOrOversizedDataArtIsRejected() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let remote = BridgeTheme(
        tokens: .workbench,
        artBlobURL: nil,
        artDataURL: "data:text/html;base64,PHNjcmlwdD4="
    )
    #expect(throws: ThemeCompilationError.invalidArtDataURL) {
        try ThemeCompiler.bundled().compile(theme: remote, profile: profile)
    }

    let oversized = BridgeTheme(
        tokens: .workbench,
        artBlobURL: nil,
        artDataURL: "data:image/png;base64," + Data(repeating: 0, count: 1_048_577).base64EncodedString()
    )
    #expect(throws: ThemeCompilationError.invalidArtDataURL) {
        try ThemeCompiler.bundled().compile(theme: oversized, profile: profile)
    }
}
