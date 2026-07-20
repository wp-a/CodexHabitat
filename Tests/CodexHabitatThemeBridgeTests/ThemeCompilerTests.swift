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
    #expect(css.contains("--habitat-home-art-position: 80% 42%"))
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
    #expect(framed.contains("body::before"))
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
func immersiveHomeHeaderAcceptsTheTypedTransparentRange() throws {
    let appearance = HabitatThemeAppearance(
        category: .custom,
        styleFamily: .gameCinematic,
        background: "background.jpg",
        artFocus: HabitatThemeFocalPoint(x: 0.8, y: 0.45),
        safeSide: .leading,
        backgroundStrength: 0.42,
        panelOpacity: 0.88,
        blurRadius: 8,
        density: .comfortable,
        homeMode: .immersive,
        headerOpacity: 0.18
    )
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )

    let css = try ThemeCompiler.bundled().compile(
        theme: BridgeTheme(
            tokens: .workbench,
            appearance: BridgeThemeAppearance(appearance),
            artBlobURL: nil
        ),
        profile: profile
    )

    #expect(css.contains("--habitat-header-opacity: 18%"))
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
    #expect(current.maximumVersionExclusive == "26.715.31925")
    #expect(current.selectors.sidebar == legacy.selectors.sidebar)
    #expect(current.selectors.appShell == nil)

    let exactBuild = try #require(store.profile(forVersion: "26.715.31925"))
    #expect(exactBuild.id == "codex-26.715.31925")
    #expect(exactBuild.selectors.appShell == "#root")
    #expect(exactBuild.selectors.userMessageSurface == "[data-user-message-bubble]")
    #expect(exactBuild.selectors.messageSurface == "[data-content-search-unit-key]")
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
func compiledSceneSpansTheWholeWindow() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "workbench"))

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)

    #expect(css.contains("habitat-scene-canvas"))
    #expect(css.contains(profile.selectors.appShell ?? "missing-app-shell"))
    #expect(css.contains("position: fixed"))
    #expect(css.contains("inset: 0"))
    #expect(css.contains("pointer-events: none"))
    #expect(css.contains("--habitat-home-art-scale"))
    #expect(css.contains("--habitat-task-art-scale"))
    #expect(css.contains("--habitat-task-content-opacity"))
    #expect(!css.contains("--habitat-route-veil"))
    #expect(css.components(separatedBy: "var(--habitat-art-background)").count - 1 == 1)
    let shell = try #require(profile.selectors.appShell)
    let artwork = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"] \(shell)::before",
        in: css
    )
    #expect(!artwork.contains("transition:"))
}

@Test
func taskSceneKeepsArtVisibleAcrossTheTranscript() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "workbench"))

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let transcript = try #require(profile.selectors.taskTranscript)

    #expect(css.contains("--habitat-task-content-opacity: 68%"))
    #expect(css.contains(transcript))
    #expect(css.contains("var(--habitat-task-content-opacity)"))
    #expect(css.contains("--habitat-task-sidebar-opacity: 74%"))
    #expect(css.contains("--habitat-task-header-opacity: 64%"))
    #expect(!css.contains("80.68%"))
    #expect(!css.contains("--habitat-route-veil"))
}

@Test
func taskRequestCardsKeepAReadableIndependentSurface() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "retro-messenger"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"task\"]"
    let requestSurface = try #require(profile.selectors.userMessageSurface)
    let selector = "\(root) \(requestSurface)"
    let rule = try cssRuleBody(selector: selector, in: css)

    #expect(rule.contains(
        "background-color: color-mix(in srgb, var(--habitat-panel) 88%, transparent)"
    ))
    #expect(!css.contains("\(profile.selectors.threadScroll) :where(article"))
}

@Test
func immersiveHomeLetsTheContinuousSceneOwnLargeSurfaces() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "workbench"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"]"
    let homeContent = try #require(profile.selectors.homeContent)

    let contentRules = try cssRuleBodies(selector: "\(root) \(homeContent)", in: css)
    let headerRules = try cssRuleBodies(selector: "\(root) \(profile.selectors.header)", in: css)

    #expect(contentRules.contains { rule in
        rule.contains("background-color: transparent")
            && rule.contains("background-image: none")
            && rule.contains("backdrop-filter: none")
    })
    #expect(headerRules.contains { rule in
        rule.contains("background-color: transparent")
            && rule.contains("background-image: none")
            && rule.contains("border-bottom-color: transparent")
            && rule.contains("box-shadow: none")
    })
}

@Test
func ambientTaskWithoutASafeSidePreservesTheConfiguredReadingOpacity() throws {
    let appearance = HabitatThemeAppearance(
        category: .custom,
        styleFamily: .gameCinematic,
        background: "background.jpg",
        artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
        safeSide: .none,
        backgroundStrength: 0.42,
        panelOpacity: 0.88,
        blurRadius: 0,
        density: .comfortable,
        taskMode: .ambient,
        taskContentOpacity: 0.84
    )
    let css = try ThemeCompiler.bundled().compile(
        theme: BridgeTheme(
            tokens: .workbench,
            appearance: BridgeThemeAppearance(appearance),
            artBlobURL: nil
        ),
        profile: try currentCompleteSurfaceProfile()
    )

    #expect(css.contains("--habitat-task-content-opacity: 84%"))
    #expect(css.contains(
        "), linear-gradient(color-mix(in srgb, var(--habitat-surface) var(--habitat-task-content-opacity), transparent)"
    ))
}

@Test
func taskModesUseRouteSpecificReadingScrimsInsteadOfOneOpaqueTranscriptSlab() throws {
    let profile = try currentCompleteSurfaceProfile()
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"task\"]"
    let selector = "\(root) \(profile.selectors.threadScroll)"

    let ambientCSS = try ThemeCompiler.bundled().compile(
        theme: try #require(BridgeTheme.builtIn(id: "workbench")),
        profile: profile
    )
    let ambientRules = try cssRuleBodies(selector: selector, in: ambientCSS)
    #expect(ambientCSS.contains("--habitat-task-reading-scrim:"))
    #expect(ambientRules.contains { rule in
        rule.contains("background-color: transparent")
            && rule.contains("background-image: var(--habitat-task-reading-scrim)")
    })

    let bannerCSS = try ThemeCompiler.bundled().compile(
        theme: try #require(BridgeTheme.builtIn(id: "arcade-signal")),
        profile: profile
    )
    let bannerRules = try cssRuleBodies(selector: selector, in: bannerCSS)
    #expect(bannerRules.contains { rule in
        rule.contains("background-color: transparent")
            && rule.contains("background-image: linear-gradient(to bottom")
    })

    let offAppearance = HabitatThemeAppearance(
        category: .custom,
        styleFamily: .cozyWorld,
        background: "background.jpg",
        artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
        safeSide: .leading,
        backgroundStrength: 0.42,
        panelOpacity: 0.88,
        blurRadius: 12,
        density: .comfortable,
        homeMode: .quiet,
        taskMode: .off
    )
    let offCSS = try ThemeCompiler.bundled().compile(
        theme: BridgeTheme(
            tokens: .workbench,
            appearance: BridgeThemeAppearance(offAppearance),
            artBlobURL: nil
        ),
        profile: profile
    )
    let offRules = try cssRuleBodies(selector: selector, in: offCSS)
    #expect(offRules.contains { rule in
        rule.contains("background-color: color-mix(in srgb, var(--habitat-surface) 96%, transparent)")
            && rule.contains("background-image: none")
    })
}

@Test
func framedSceneScalesOnlyArtworkAndKeepsItsFrameStable() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "retro-messenger"))

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let homeRoot = "\(root)[data-codex-habitat-route=\"home\"]"
    let shell = try #require(profile.selectors.appShell)
    let artwork = try cssRuleBody(selector: "\(homeRoot) \(shell)::before", in: css)
    let overlay = try cssRuleBody(selector: "\(homeRoot) \(shell)::after", in: css)

    #expect(artwork.contains("transform: scale(var(--habitat-home-art-scale))"))
    #expect(!artwork.contains("border:"))
    #expect(!artwork.contains("var(--habitat-safe-scrim)"))
    #expect(overlay.contains("inset: 16px"))
    #expect(overlay.contains("border-radius: 12px"))
    #expect(overlay.contains("var(--habitat-safe-scrim)"))
    #expect(!overlay.contains("transform:"))
    #expect(!overlay.contains("var(--habitat-home-strength)"))
}

@Test
func trailingHomeContentKeepsAVisibleViewportInset() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "retro-messenger"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let homeContent = try #require(profile.selectors.homeContent)
    let rule = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] \(homeContent)",
        in: css
    )

    #expect(rule.contains("margin-inline-start: auto"))
    #expect(rule.contains("margin-inline-end: clamp(16px, 2.5vw, 32px)"))
}

@Test
func routeArtworkScaleUsesTheRouteFocusAsItsTransformOrigin() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "night-shift"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let shell = try #require(profile.selectors.appShell)
    let homeArtwork = try cssRuleBody(
        selector: "\(root)[data-codex-habitat-route=\"home\"] \(shell)::before",
        in: css
    )
    let taskArtwork = try cssRuleBody(
        selector: "\(root)[data-codex-habitat-route=\"task\"] \(shell)::before",
        in: css
    )
    let taskOverlay = try cssRuleBody(
        selector: "\(root)[data-codex-habitat-route=\"task\"] \(shell)::after",
        in: css
    )

    #expect(homeArtwork.contains("background-position: var(--habitat-home-art-position)"))
    #expect(homeArtwork.contains("transform-origin: var(--habitat-home-art-position)"))
    #expect(taskArtwork.contains("background-position: var(--habitat-task-art-position)"))
    #expect(taskArtwork.contains("transform-origin: var(--habitat-task-art-position)"))
    #expect(taskArtwork.contains("mask-image: linear-gradient"))
    #expect(taskArtwork.contains("var(--habitat-task-banner-fade-start)"))
    #expect(taskArtwork.contains("var(--habitat-task-banner-fade-end)"))
    #expect(taskOverlay.contains("mask-image: linear-gradient(to bottom, black 0 46%, transparent 52%)"))
}

@Test
func bannerArtworkInsetCompensatesForFocusAnchoredScale() {
    for focusY in [0.0, 0.44, 1.0] {
        for scale in [1.0, 1.06, 1.35] {
            let inset = ThemeCompiler.bannerArtworkBottomInset(
                focusY: focusY,
                scale: scale
            )
            let localVisibleBottom = 1 - inset
            let transformedVisibleBottom = focusY + scale * (localVisibleBottom - focusY)
            #expect(abs(transformedVisibleBottom - 0.52) < 0.000_1)
            let fadeStart = ThemeCompiler.bannerArtworkLocalPosition(
                focusY: focusY,
                scale: scale,
                transformedPosition: 0.46
            )
            #expect(abs(focusY + scale * (fadeStart - focusY) - 0.46) < 0.000_1)
        }
    }
}

@Test
func compiledSurfacesOverrideHostTextClassesWithSemanticForegrounds() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "quiet-garden"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let homeContent = try #require(profile.selectors.homeContent)

    #expect(css.contains("\(root) \(profile.selectors.sidebar) :where(a, button, [role=\"button\"])"))
    #expect(css.contains("\(root) \(profile.selectors.sidebar) :where(h1, h2, h3, h4, h5, h6)"))
    #expect(css.contains("\(root)[data-codex-habitat-route=\"home\"] \(homeContent) p"))
    #expect(css.contains("\(root)[data-codex-habitat-route=\"task\"] \(profile.selectors.threadScroll) p"))
    #expect(css.contains("\(root) \(profile.selectors.popover) > *"))
    #expect(css.contains("color: var(--habitat-muted-text)"))
    #expect(!css.contains("\(profile.selectors.sidebar) > :last-child"))

    let taskParagraph = try cssRuleBody(
        selector: "\(root)[data-codex-habitat-route=\"task\"] \(profile.selectors.threadScroll) p",
        in: css
    )
    #expect(taskParagraph.contains("color: var(--habitat-text)"))
    #expect(!taskParagraph.contains("color: var(--habitat-muted-text)"))
}

@Test
func routeStrengthDoesNotWeakenTheReadabilityVignette() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "quiet-garden"))

    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let shell = try #require(profile.selectors.appShell)
    let baseArtwork = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"] \(shell)::before",
        in: css
    )
    let baseOverlay = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"] \(shell)::after",
        in: css
    )

    #expect(baseArtwork.contains("var(--habitat-art-background)"))
    #expect(!baseArtwork.contains("var(--habitat-safe-scrim)"))
    #expect(baseOverlay.contains("var(--habitat-safe-scrim)"))
    #expect(!baseOverlay.contains("var(--habitat-home-strength)"))
    #expect(!baseOverlay.contains("var(--habitat-task-strength)"))
}

@Test
func fullWindowSceneUsesLayeredReadabilityAndNarrowFallbacks() throws {
    let profile = try currentCompleteSurfaceProfile()
    let css = try ThemeCompiler.bundled().compile(
        theme: try #require(BridgeTheme.builtIn(id: "workbench")),
        profile: profile
    )
    let root = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"]",
        in: css
    )

    #expect(root.contains("--habitat-safe-scrim: linear-gradient(to bottom"))
    #expect(root.contains("), linear-gradient(to right"))
    #expect(root.contains("--habitat-task-reading-scrim: linear-gradient(to bottom"))
    #expect(css.contains("@media (max-width: 1180px)"))
    #expect(css.contains("max-width: min(calc(100% - 32px), 72%)"))
    #expect(css.contains("@media (max-width: 900px)"))
    #expect(css.contains("max-width: calc(100% - 24px)"))
    #expect(css.contains("backdrop-filter: none"))
}

@Test
func largeSidebarNeverReceivesBackdropBlur() throws {
    let profile = try currentCompleteSurfaceProfile()

    for material in [HabitatThemeChromeMaterial.tinted, .glass] {
        let treatment = ThemeCompiler.chromeTreatment(for: material, profile: profile)
        let sidebar = try cssRuleBody(
            selector: "html[data-codex-habitat-theme=\"1\"] \(profile.selectors.sidebar)",
            in: treatment
        )
        #expect(sidebar.contains("backdrop-filter: none"))
        #expect(!sidebar.contains("blur("))
    }
}

@Test
func everyStyleRecipeCoversRequiredHostSurfaces() throws {
    let profile = try currentCompleteSurfaceProfile()
    let selectors = profile.selectors.allSelectors.filter {
        $0 != profile.selectors.homeMarker
    }
    let recipes = HabitatThemeStyleFamily.allCases.map {
        ThemeCompiler.styleTreatment(for: $0, profile: profile)
    }

    for (family, recipe) in zip(HabitatThemeStyleFamily.allCases, recipes) {
        for selector in selectors {
            #expect(recipe.contains(selector), "\(family.rawValue) omits \(selector)")
        }
        for surface in [
            "shell", "sidebar", "header", "stage", "transcript", "content",
            "home-actions", "composer", "selected-navigation", "fades-and-resize",
        ] {
            #expect(
                recipe.contains("habitat-surface: \(surface)"),
                "\(family.rawValue) omits the \(surface) surface recipe"
            )
        }
        for state in ["primary", "focus", "selected", "warning", "destructive"] {
            #expect(
                recipe.contains("habitat-semantic-state: \(state)"),
                "\(family.rawValue) omits the \(state) semantic state"
            )
        }

        let rootSelector = "html[data-codex-habitat-theme=\"1\"] "
            + (profile.selectors.appShell ?? "missing-app-shell")
        let shellRule = try cssRuleBody(selector: rootSelector, in: recipe)
        #expect(!shellRule.contains("border-right"))
        #expect(!shellRule.contains("box-shadow"))
        #expect(!recipe.contains(profile.selectors.homeMarker))
        #expect(!recipe.contains("text-token-"))
        #expect(!recipe.contains("bg-token-"))
        #expect(!recipe.contains("[data-state="))
    }

    let normalized = recipes.map(normalizedStyleRecipe)
    #expect(Set(normalized).count == HabitatThemeStyleFamily.allCases.count)
}

@Test
func everyStyleFamilyOwnsDistinctHomeActionChrome() throws {
    let profile = try currentCompleteSurfaceProfile()
    let suggestions = try #require(profile.selectors.homeSuggestions)
    let selector = "html[data-codex-habitat-theme=\"1\"] \(suggestions) :where(button, [role=\"button\"])"
    let rules = try HabitatThemeStyleFamily.allCases.map { family in
        let treatment = ThemeCompiler.styleTreatment(for: family, profile: profile)
        let rule = try cssRuleBody(selector: selector, in: treatment)
        #expect(rule.contains("color: var(--habitat-text)"), "\(family.rawValue) keeps host action text")
        #expect(rule.contains("background-color:"), "\(family.rawValue) has no action fill")
        #expect(rule.contains("border"), "\(family.rawValue) has no action structure")
        #expect(!rule.contains("backdrop-filter"), "\(family.rawValue) blurs a repeated action")
        return normalizedStyleRecipe(rule)
    }

    #expect(Set(rules).count == HabitatThemeStyleFamily.allCases.count)
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

private func currentCompleteSurfaceProfile() throws -> CompatibilityProfile {
    try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
}

private func normalizedStyleRecipe(_ recipe: String) -> String {
    recipe
        .replacingOccurrences(
            of: #"/\*[\s\S]*?\*/"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"#[0-9A-Fa-f]{3,8}"#,
            with: "<color>",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"data:[^)\"']+"#,
            with: "<data>",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"-?[0-9]+(?:\.[0-9]+)?(?:px|%|rem)?"#,
            with: "<number>",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func cssRuleBody(selector: String, in css: String) throws -> String {
    try #require(cssRuleBodies(selector: selector, in: css).first)
}

private func cssRuleBodies(selector: String, in css: String) throws -> [String] {
    let escaped = NSRegularExpression.escapedPattern(for: selector)
    let expression = try NSRegularExpression(
        pattern: escaped + #"\s*\{([^}]*)\}"#,
        options: .dotMatchesLineSeparators
    )
    let range = NSRange(css.startIndex..<css.endIndex, in: css)
    return try expression.matches(in: css, range: range).map { match in
        let bodyRange = try #require(Range(match.range(at: 1), in: css))
        return String(css[bodyRange])
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
