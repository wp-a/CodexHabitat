import CryptoKit
import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Test
func bundledProfileCompilesOnlyHostSelectorsApprovedTokensAndLocalBlobArt() throws {
    let store = try CompatibilityProfileStore.bundled()
    let profile = try #require(store.profile(forVersion: "26.707.91948"))
    let definition = try #require(BuiltInThemeCatalog.definition(id: "night-shift"))
    let theme = BridgeTheme(
        tokens: BridgeThemeTokens(palette: definition.palette),
        appearance: BridgeThemeAppearance(definition.appearance(background: "background.jpg")),
        artBlobURL: "blob:app://codex/habitat-art-1"
    )

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)

    #expect(css.contains("aside.app-shell-left-panel"))
    #expect(css.contains("main.main-surface"))
    #expect(css.contains(".composer-surface-chrome"))
    #expect(profile.selectors.homeMarker == "[data-testid=\"home-icon\"]")
    #expect(css.contains(definition.palette.panelAlt))
    #expect(css.contains(definition.palette.secondary))
    #expect(css.contains(definition.palette.highlight))
    #expect(css.contains("blob:app://codex/habitat-art-1"))
    #expect(css.contains("habitat-style-family: gameCinematic"))
    #expect(css.contains("--habitat-art-position: 76% 42%"))
    #expect(css.contains("--habitat-tinted-blur-radius: 5.5px"))
    #expect(!css.contains("* 0.55"))
    #expect(!css.contains("soft-light"))
    #expect(!css.contains("{{"))
    #expect(!css.contains("@import"))
    #expect(!css.contains("https://"))
    #expect(!css.contains("http://"))
}

@Test
func fourPrototypesCompileDistinctRouteAwareWindowTreatments() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31251")
    )
    let identifiers = ["workbench", "retro-messenger", "arcade-signal", "quiet-garden"]
    let styles = try identifiers.map { identifier in
        let theme = try #require(BridgeTheme.builtIn(id: identifier))
        let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
        #expect(css.contains("data-codex-habitat-route=\"home\""))
        #expect(css.contains("data-codex-habitat-route=\"task\""))
        #expect(css.contains("--habitat-home-strength"))
        #expect(css.contains("--habitat-task-strength"))
        #expect(css.contains("--habitat-sidebar-opacity"))
        #expect(css.contains("--habitat-header-opacity"))
        #expect(css.contains("--habitat-composer-opacity"))
        #expect(css.contains("habitat-home-mode: \(theme.appearance.homeMode.rawValue)"))
        #expect(css.contains("habitat-task-mode: \(theme.appearance.taskMode.rawValue)"))
        #expect(css.contains("habitat-chrome-material: \(theme.appearance.chromeMaterial.rawValue)"))
        return css
    }

    #expect(Set(styles).count == identifiers.count)

    let framed = styles[1]
    #expect(framed.contains("habitat-home-mode: framed"))
    #expect(framed.contains("main.main-surface::before"))
    #expect(framed.contains("inset: 16px"))
    #expect(framed.contains("pointer-events: none"))
    #expect(framed.contains("background-image: none"))
}

@Test
func legacyMinimumBackgroundStrengthCompilesWithBoundedTaskFallback() throws {
    let appearance = HabitatThemeAppearance(
        category: .custom,
        styleFamily: .cozyWorld,
        background: "background.jpg",
        artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
        safeSide: .leading,
        backgroundStrength: 0.10,
        panelOpacity: 0.65,
        blurRadius: 0,
        density: .comfortable
    )
    let theme = BridgeTheme(
        tokens: .workbench,
        appearance: BridgeThemeAppearance(appearance),
        artBlobURL: nil
    )
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)

    #expect(css.contains("--habitat-task-strength: 10%"))
}

@Test
func unknownCodexVersionsFailClosed() throws {
    let store = try CompatibilityProfileStore.bundled()

    #expect(store.profile(forVersion: "26.708.0") == nil)
    #expect(store.profile(forVersion: "26.714.99999") == nil)
    #expect(store.profile(forVersion: "26.716.0") == nil)
    #expect(store.profile(forVersion: "999.0.0") == nil)
    #expect(store.profile(forVersion: "not-a-version") == nil)
}

@Test
func staticallyVerifiedCodexLinesResolveToNarrowProfiles() throws {
    let store = try CompatibilityProfileStore.bundled()
    let legacy = try #require(store.profile(forVersion: "26.707.91948"))
    let current = try #require(store.profile(forVersion: "26.715.31251"))

    #expect(legacy.id == "codex-26.707")
    #expect(current.id == "codex-26.715")
    #expect(current.minimumVersion == "26.715.0")
    #expect(current.maximumVersionExclusive == "26.716.0")
    #expect(current.selectors == legacy.selectors)
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
func allTwentyFourBundledThemesResolveWithRichTokensAppearanceAndJPEGArt() throws {
    #expect(BuiltInThemeCatalog.all.count == 24)
    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        #expect(theme.tokens == BridgeThemeTokens(palette: definition.palette))
        #expect(theme.appearance.styleFamily == definition.styleFamily)
        #expect(theme.artBlobURL == nil)
        let artDataURL = try #require(theme.artDataURL)
        #expect(artDataURL.hasPrefix("data:image/jpeg;base64,"))
        #expect(Data(base64Encoded: String(artDataURL.dropFirst("data:image/jpeg;base64,".count))) != nil)
        let css = try ThemeCompiler.bundled().compile(
            theme: theme,
            profile: try #require(
                try CompatibilityProfileStore.bundled().profile(
                    forVersion: "26.707.91948"
                )
            )
        )
        #expect(css.contains("data:image/jpeg;base64,"))
        #expect(css.contains("--habitat-panel: \(definition.palette.panel)"))
        #expect(css.contains("habitat-style-family: \(definition.styleFamily.rawValue)"))
    }
    #expect(BridgeTheme.builtIn(id: "unknown") == nil)
}

@Test
func everyHostOwnedStyleFamilyCompilesToADistinctTreatment() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
    )
    let treatments = HabitatThemeStyleFamily.allCases.map {
        ThemeCompiler.styleTreatment(for: $0, profile: profile)
    }

    #expect(treatments.count == 9)
    #expect(Set(treatments).count == 9)
    for (family, treatment) in zip(HabitatThemeStyleFamily.allCases, treatments) {
        #expect(treatment.contains("habitat-style-family: \(family.rawValue)"))
        #expect(treatment.contains(profile.selectors.sidebar))
        #expect(treatment.contains(profile.selectors.composer))
    }
}

@Test
func installedCustomThemeIsRevalidatedBeforeBridgeCompilation() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "CodexHabitatBridgeResolver-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let themeID = "local.theme.bridge-test"
    let packageURL = try copyBuiltInAsInstalledTheme(
        sourceID: "retro-messenger",
        targetID: themeID,
        libraryRoot: root
    )
    let resolver = BridgeThemeResolver(libraryRoot: root)

    let theme = try resolver.resolve(id: themeID)

    #expect(theme.appearance.styleFamily == .retroMessenger)
    #expect(theme.artDataURL?.hasPrefix("data:image/jpeg;base64,") == true)
    let css = try ThemeCompiler.bundled().compile(
        theme: theme,
        profile: try #require(
            try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
        )
    )
    #expect(css.contains("habitat-style-family: retroMessenger"))
    #expect(throws: BridgeThemeResolutionError.invalidThemeArt) {
        try BridgeThemeResolver(libraryRoot: root, maximumImagePixels: 100).resolve(id: themeID)
    }

    let backgroundURL = packageURL.appending(path: "background.jpg")
    var tampered = try Data(contentsOf: backgroundURL)
    tampered.append(0)
    try tampered.write(to: backgroundURL)
    #expect(throws: BridgeThemeResolutionError.invalidThemeArt) {
        try resolver.resolve(id: themeID)
    }

    let invalidImage = Data("not-an-image".utf8)
    try invalidImage.write(to: backgroundURL)
    try updateBackgroundHash(
        SHA256.hash(data: invalidImage).map { String(format: "%02x", $0) }.joined(),
        manifestURL: packageURL.appending(path: "habitat.json")
    )
    #expect(throws: BridgeThemeResolutionError.invalidThemeArt) {
        try resolver.resolve(id: themeID)
    }
}

@Test
func eightDigitProtocolColorsCompileWithoutChangingRGBColorScheme() throws {
    let palette = HabitatThemePalette(
        surface: "#10182080",
        panel: "#182633F0",
        panelAlt: "#24384AE0",
        text: "#F4FAFFFF",
        mutedText: "#A9BAC8FF",
        accent: "#16C6D9CC",
        secondary: "#FF4F9ACC",
        highlight: "#FFE45CCC",
        attention: "#FFAA33CC",
        error: "#F04455CC"
    )
    let theme = BridgeTheme(
        tokens: BridgeThemeTokens(palette: palette),
        artBlobURL: nil
    )
    let css = try ThemeCompiler.bundled().compile(
        theme: theme,
        profile: try #require(
            try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
        )
    )

    #expect(css.contains("--habitat-surface: #10182080"))
    #expect(css.contains("color-scheme: dark"))
}

@Test
func themeJSONCannotInjectNestedAppearanceCSS() {
    let malicious = Data(#"""
    {
      "tokens": {
        "surface": "#101820", "panel": "#182633", "panelAlt": "#24384A",
        "text": "#F4FAFF", "mutedText": "#A9BAC8", "accent": "#16C6D9",
        "secondary": "#FF4F9A", "highlight": "#FFE45C",
        "attention": "#FFAA33", "error": "#F04455"
      },
      "appearance": {
        "styleFamily": "arcade", "artFocus": {"x": 0.7, "y": 0.4},
        "safeSide": "leading", "backgroundStrength": 0.4, "panelOpacity": 0.9,
        "blurRadius": 10, "density": "comfortable", "css": "body { display: none }"
      }
    }
    """#.utf8)

    #expect(throws: ThemeCompilationError.unknownThemeField("appearance.css")) {
        try BridgeThemeDecoder().decode(malicious)
    }
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

private func copyBuiltInAsInstalledTheme(
    sourceID: String,
    targetID: String,
    libraryRoot: URL
) throws -> URL {
    let sourceDirectory = "Resources/Themes/\(sourceID)"
    let manifestURL = try #require(PackagedResourceLocator.url(
        forResource: "habitat",
        withExtension: "json",
        subdirectory: sourceDirectory,
        packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
    ))
    let backgroundURL = try #require(PackagedResourceLocator.url(
        forResource: "background",
        withExtension: "jpg",
        subdirectory: sourceDirectory,
        packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
    ))
    let target = libraryRoot
        .appending(path: targetID, directoryHint: .isDirectory)
        .appending(path: "1.0.0", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try FileManager.default.copyItem(
        at: backgroundURL,
        to: target.appending(path: "background.jpg")
    )
    var manifest = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
    )
    manifest["id"] = targetID
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: target.appending(path: "habitat.json"))
    return target
}

private func updateBackgroundHash(_ hash: String, manifestURL: URL) throws {
    var manifest = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
    )
    var assets = try #require(manifest["assets"] as? [[String: Any]])
    let index = try #require(assets.firstIndex { $0["path"] as? String == "background.jpg" })
    assets[index]["sha256"] = hash
    manifest["assets"] = assets
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: manifestURL)
}
