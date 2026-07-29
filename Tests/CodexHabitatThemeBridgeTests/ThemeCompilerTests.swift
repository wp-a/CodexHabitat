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
    #expect(css.contains("--habitat-art-saturation:"))
    #expect(css.contains("--habitat-art-contrast:"))
    #expect(css.contains("--habitat-art-exposure:"))
    #expect(css.contains("--habitat-localized-scrim-strength:"))
    #expect(!css.contains("* 0.55"))
    #expect(!css.contains("soft-light"))
    #expect(!css.contains("{{"))
    #expect(!css.contains("@import"))
    #expect(!css.contains("https://"))
    #expect(!css.contains("http://"))
}

@Test
func everyBuiltInThemeCompilesTheSharedSemanticMaterialShell() throws {
    let store = try CompatibilityProfileStore.bundled()
    let profile = try #require(store.profile(forVersion: "26.715.31925"))
    let compiler = try ThemeCompiler.bundled()
    let requiredTokens = [
        "--habitat-stage-scrim:",
        "--habitat-sidebar-chrome:",
        "--habitat-task-sidebar-chrome:",
        "--habitat-header-chrome:",
        "--habitat-task-header-chrome:",
        "--habitat-action-fill:",
        "--habitat-composer-fill:",
        "--habitat-popover-fill:",
        "--habitat-divider:",
        "--habitat-selected-fill:",
        "--habitat-focus-ring:",
        "--habitat-ambient-shadow:",
        "--habitat-inner-highlight:",
    ]

    #expect(BuiltInThemeCatalog.all.count == 24)
    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        let css = try compiler.compile(theme: theme, profile: profile)

        for token in requiredTokens {
            #expect(css.contains(token), "\(definition.id) omits \(token)")
        }
    }
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
func compiledHeadersConsumeTheTypedRouteOpacityVariables() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
    let theme = try #require(BridgeTheme.builtIn(id: "workbench"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let header = profile.selectors.header
    let homeRule = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"] \(header)",
        in: css
    )
    let taskRule = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"task\"] \(header)",
        in: css
    )

    #expect(homeRule.contains("var(--habitat-header-chrome)"))
    #expect(taskRule.contains("var(--habitat-task-header-chrome)"))
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
func compilerConsumesTheSharedNonGeometricSurfaceRecipe() throws {
    let profile = try currentCompleteSurfaceProfile()
    let suggestions = try #require(profile.selectors.homeSuggestions)
    let selectedNavigation = try #require(profile.selectors.selectedNavigation)
    let root = "html[data-codex-habitat-theme=\"1\"]"

    for family in HabitatThemeStyleFamily.allCases {
        let recipe = family.surfaceRecipe
        let treatment = ThemeCompiler.styleTreatment(for: family, profile: profile)
        let header = try cssRuleBody(
            selector: "\(root) \(profile.selectors.header)",
            in: treatment
        )
        let action = try cssRuleBody(
            selector: "\(root) \(suggestions) :where(button, [role=\"button\"])",
            in: treatment
        )
        let composer = try cssRuleBody(
            selector: "\(root) \(profile.selectors.composer)",
            in: treatment
        )
        let selected = try cssRuleBody(
            selector: "\(root) \(selectedNavigation)",
            in: treatment
        )
        let focus = try cssRuleBody(selector: "\(root) :focus-visible", in: treatment)

        #expect(treatment.contains("habitat-surface-recipe: \(recipe.signature)"))
        #expect(header.contains("border-bottom-width: \(cssNumber(recipe.headerEdgeWidth))px"))
        #expect(header.contains("border-bottom-style: \(cssLineStyle(recipe.headerLineStyle))"))
        #expect(action.contains("border-radius: \(cssNumber(recipe.actionRadius))px"))
        #expect(action.contains("border: \(cssNumber(recipe.actionEdgeWidth))px solid"))
        #expect(action.contains("border-style: \(cssLineStyle(recipe.actionLineStyle))"))
        #expect(treatment.contains("border-radius: \(cssNumber(recipe.readingRadius))px; border-width: \(cssNumber(recipe.readingEdgeWidth))px; border-style: \(cssLineStyle(recipe.readingLineStyle));"))
        #expect(composer.contains("border-radius: \(cssNumber(recipe.composerRadius))px"))
        #expect(composer.contains("border: \(cssNumber(recipe.composerEdgeWidth))px solid"))
        #expect(selected.contains("inset 0 0 0 1px"))
        #expect(selected.contains("border-radius: \(cssNumber(recipe.selectedRadius))px"))
        #expect(focus.contains("outline-style: \(cssFocusStyle(recipe.focusStyle))"))
        #expect(focus.contains("var(--habitat-focus-ring)"))
    }
}

@Test
func readableTextUsesOneShortShadowLayer() throws {
    let treatment = ThemeCompiler.surfaceTreatment(profile: try currentCompleteSurfaceProfile())
    let expression = try NSRegularExpression(pattern: #"text-shadow:\s*([^;]+)"#)
    let range = NSRange(treatment.startIndex..<treatment.endIndex, in: treatment)
    let shadows = expression.matches(in: treatment, range: range).compactMap { match -> String? in
        guard let shadowRange = Range(match.range(at: 1), in: treatment) else { return nil }
        return String(treatment[shadowRange])
    }

    #expect(!shadows.isEmpty)
    for shadow in shadows {
        #expect(topLevelCommaCount(in: shadow) == 0, "text shadow must have exactly one layer")
        #expect((try cssPixelLengths(in: shadow).max() ?? 0) <= 4, "text shadow must remain short")
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

    #expect(rule.contains("background-color: var(--habitat-control-surface)"))
    #expect(rule.contains("border-color: var(--habitat-divider)"))
    #expect(!css.contains("\(profile.selectors.threadScroll) :where(article"))
}

@Test
func taskResponseSurfacesUseAnUnframedEditorialReadingSurface() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "aqua-pulse"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"task\"]"
    let responseSurface = try #require(profile.selectors.messageSurface)
    let selector = "\(root) \(responseSurface)"
    let rule = try cssRuleBody(selector: selector, in: css)

    #expect(rule.contains("background-color: transparent"))
    #expect(rule.contains("border-color: transparent"))
    #expect(rule.contains("box-shadow: none"))
    #expect(rule.contains("backdrop-filter: none"))
}

@Test
func composerPlaceholderUsesOpaqueSemanticMutedText() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "workbench"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let selector = "\(root) \(profile.selectors.composer) :where(textarea, input)::placeholder"
    let rule = try cssRuleBody(selector: selector, in: css)

    #expect(rule.contains("color: var(--habitat-readable-muted)"))
    #expect(rule.contains("opacity: 1"))
}

@Test
func homeTextUsesABoundedSurfaceHaloWithoutOwningTheContainer() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "quiet-garden"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"]"
    let homeContent = try #require(profile.selectors.homeContent)
    let selector = "\(root) \(homeContent) :where(h1, h2, h3, p)"
    let rule = try cssRuleBody(selector: selector, in: css)

    #expect(rule.contains("text-shadow:"))
    #expect(rule.contains("var(--habitat-surface)"))
    #expect(!rule.contains("background"))
}

@Test
func homeSubtitleUsesTheSceneScrimInsteadOfALabelBackground() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "quiet-garden"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"]"
    let homeContent = try #require(profile.selectors.homeContent)
    let rule = try cssRuleBody(selector: "\(root) \(homeContent) p", in: css)

    #expect(rule.contains("background-image: none"))
    #expect(rule.contains("padding: 0"))
    #expect(!rule.contains("linear-gradient"))
}

@Test
func submitControlsUseAccessibleForegrounds() throws {
    let profile = try currentCompleteSurfaceProfile()
    let compiler = try ThemeCompiler.bundled()
    let greenChat = try #require(BridgeTheme.builtIn(id: "green-chat-desk"))
    let workbench = try #require(BridgeTheme.builtIn(id: "workbench"))
    let quietGarden = try #require(BridgeTheme.builtIn(id: "quiet-garden"))
    let crimsonMecha = try #require(BridgeTheme.builtIn(id: "crimson-mecha"))

    let greenCSS = try compiler.compile(theme: greenChat, profile: profile)
    let darkCSS = try compiler.compile(theme: workbench, profile: profile)
    let quietCSS = try compiler.compile(theme: quietGarden, profile: profile)
    let crimsonCSS = try compiler.compile(theme: crimsonMecha, profile: profile)
    #expect(greenCSS.contains("--habitat-on-accent: #000000"))
    #expect(darkCSS.contains("--habitat-on-accent: #171A21"))
    #expect(quietCSS.contains("--habitat-on-accent: #000000"))
    #expect(crimsonCSS.contains("--habitat-on-accent: #000000"))
    #expect(greenCSS.contains("color: var(--habitat-on-accent)"))
}

@Test
func homeActionControlsUseAnOpaqueMaximumContrastForeground() throws {
    let profile = try currentCompleteSurfaceProfile()
    let compiler = try ThemeCompiler.bundled()
    let win95 = try #require(BridgeTheme.builtIn(id: "win95-workbench"))
    let blockFrontier = try #require(BridgeTheme.builtIn(id: "block-frontier"))
    let win95CSS = try compiler.compile(theme: win95, profile: profile)
    let blockCSS = try compiler.compile(theme: blockFrontier, profile: profile)

    #expect(win95CSS.contains("--habitat-home-action-background: #F2F2F1"))
    #expect(win95CSS.contains("--habitat-home-action-text: #000000"))
    #expect(blockCSS.contains("--habitat-home-action-background: #1F2922"))
    #expect(blockCSS.contains("--habitat-home-action-text: #FFFFFF"))
    #expect(win95CSS.contains("color: var(--habitat-home-action-text)"))
    #expect(win95CSS.contains("background-color: var(--habitat-action-fill)"))
}

@Test
func submitControlDoesNotInheritTheComposerMaterial() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "workbench"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let composer = try #require(
        cssRuleBodies(selector: "\(root) \(profile.selectors.composer)", in: css).last
    )
    let submit = try cssRuleBody(selector: "\(root) button[type=\"submit\"]", in: css)

    #expect(composer.contains("var(--habitat-composer-fill)"))
    #expect(submit.contains("background-color: var(--habitat-submit-accent)"))
    #expect(submit.contains("border-radius: 999px"))
    #expect(!submit.contains("var(--habitat-control-surface)"))
    #expect(!submit.contains("box-shadow: inset 0 1px 0"))
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
func trailingSafeSideShapesTheScrimWithoutMovingHomeContent() throws {
    let profile = try currentCompleteSurfaceProfile()
    let theme = try #require(BridgeTheme.builtIn(id: "retro-messenger"))
    let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
    let homeContent = try #require(profile.selectors.homeContent)
    let root = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"]",
        in: css
    )
    let rule = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] \(homeContent)",
        in: css
    )

    #expect(theme.appearance.safeSide == .trailing)
    #expect(root.contains("--habitat-safe-scrim:"))
    #expect(root.contains("linear-gradient(to left"))
    #expect(!rule.contains("margin-inline"))
    #expect(!rule.contains("max-width"))
}

@Test
func homeSafeScrimUsesContentOpacityForTheReadingWash() throws {
    let profile = try currentCompleteSurfaceProfile()
    let cases: [(HabitatThemeSafeSide, String, String?)] = [
        (.leading, "linear-gradient(to right", "52%"),
        (.trailing, "linear-gradient(to left", "52%"),
        (.center, "radial-gradient(ellipse at center", "56%"),
        (.none, "linear-gradient(color-mix", nil),
    ]

    for (safeSide, gradient, vignetteStop) in cases {
        let appearance = HabitatThemeAppearance(
            category: .custom,
            styleFamily: .cozyWorld,
            background: "background.jpg",
            artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
            safeSide: safeSide,
            backgroundStrength: 0.42,
            panelOpacity: 0.88,
            blurRadius: 8,
            density: .comfortable,
            homeContentOpacity: 0.67,
            vignetteStrength: 0.23
        )
        let css = try ThemeCompiler.bundled().compile(
            theme: BridgeTheme(
                tokens: .workbench,
                appearance: BridgeThemeAppearance(appearance),
                artBlobURL: nil
            ),
            profile: profile
        )
        let root = try cssRuleBody(
            selector: "html[data-codex-habitat-theme=\"1\"]",
            in: css
        )
        let scrim = try cssDeclarationValue("--habitat-safe-scrim", in: root)

        #expect(scrim.contains(gradient), "\(safeSide.rawValue) loses its reading wash shape")
        #expect(
            scrim.contains("var(--habitat-home-content-opacity)"),
            "\(safeSide.rawValue) does not consume homeContentOpacity"
        )
        #expect(!scrim.contains("linear-gradient(transparent, transparent)"))
        if let vignetteStop {
            #expect(scrim.contains("var(--habitat-localized-scrim-strength)"))
            #expect(scrim.contains(vignetteStop), "\(safeSide.rawValue) loses its vignette falloff")
        } else {
            #expect(!scrim.contains("var(--habitat-localized-scrim-strength)"))
        }
    }
}

@Test
func changingHomeContentOpacityDoesNotChangeTaskScrims() throws {
    let profile = try currentCompleteSurfaceProfile()
    func compiledCSS(homeContentOpacity: Double) throws -> String {
        let appearance = HabitatThemeAppearance(
            category: .custom,
            styleFamily: .cozyWorld,
            background: "background.jpg",
            artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
            safeSide: .leading,
            backgroundStrength: 0.42,
            panelOpacity: 0.88,
            blurRadius: 8,
            density: .comfortable,
            homeContentOpacity: homeContentOpacity,
            taskContentOpacity: 0.72,
            vignetteStrength: 0.23
        )
        return try ThemeCompiler.bundled().compile(
            theme: BridgeTheme(
                tokens: .workbench,
                appearance: BridgeThemeAppearance(appearance),
                artBlobURL: nil
            ),
            profile: profile
        )
    }

    let lowRoot = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"]",
        in: compiledCSS(homeContentOpacity: 0.40)
    )
    let highRoot = try cssRuleBody(
        selector: "html[data-codex-habitat-theme=\"1\"]",
        in: compiledCSS(homeContentOpacity: 0.78)
    )
    let lowHomeOpacity = try cssDeclarationValue("--habitat-home-content-opacity", in: lowRoot)
    let highHomeOpacity = try cssDeclarationValue("--habitat-home-content-opacity", in: highRoot)
    let lowHomeScrim = try cssDeclarationValue("--habitat-safe-scrim", in: lowRoot)
    let highHomeScrim = try cssDeclarationValue("--habitat-safe-scrim", in: highRoot)
    let lowTaskSafeScrim = try cssDeclarationValue("--habitat-task-safe-scrim", in: lowRoot)
    let highTaskSafeScrim = try cssDeclarationValue("--habitat-task-safe-scrim", in: highRoot)
    let lowTaskReadingScrim = try cssDeclarationValue("--habitat-task-reading-scrim", in: lowRoot)
    let highTaskReadingScrim = try cssDeclarationValue("--habitat-task-reading-scrim", in: highRoot)

    #expect(lowHomeOpacity != highHomeOpacity)
    #expect(lowHomeScrim == highHomeScrim)
    #expect(lowHomeScrim.contains("var(--habitat-home-content-opacity)"))
    #expect(lowTaskSafeScrim == highTaskSafeScrim)
    #expect(lowTaskReadingScrim == highTaskReadingScrim)
    #expect(!lowTaskSafeScrim.contains("var(--habitat-home-content-opacity)"))
    #expect(!lowTaskReadingScrim.contains("var(--habitat-home-content-opacity)"))
}

@Test
func taskModesUseTaskOnlyScrimsOnTheirOverlayAndTranscript() throws {
    let profile = try currentCompleteSurfaceProfile()
    let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"task\"]"
    let shell = try #require(profile.selectors.appShell)
    let transcript = try #require(profile.selectors.taskTranscript)

    for mode in [HabitatThemeTaskMode.ambient, .banner, .off] {
        let appearance = HabitatThemeAppearance(
            category: .custom,
            styleFamily: .cozyWorld,
            background: "background.jpg",
            artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
            safeSide: .leading,
            backgroundStrength: 0.42,
            panelOpacity: 0.88,
            blurRadius: 8,
            density: .comfortable,
            taskMode: mode
        )
        let css = try ThemeCompiler.bundled().compile(
            theme: BridgeTheme(
                tokens: .workbench,
                appearance: BridgeThemeAppearance(appearance),
                artBlobURL: nil
            ),
            profile: profile
        )
        let overlay = try cssRuleBody(selector: "\(root) \(shell)::after", in: css)

        #expect(overlay.contains("background-image: var(--habitat-task-safe-scrim)"))
        #expect(!overlay.contains("background-image: var(--habitat-safe-scrim)"))
        if mode != .off {
            let transcriptRules = try cssRuleBodies(selector: "\(root) \(transcript)", in: css)
            let expectedScrim = mode == .ambient
                ? "var(--habitat-task-reading-scrim)"
                : "var(--habitat-task-safe-scrim)"
            #expect(transcriptRules.contains { $0.contains(expectedScrim) })
        }
    }
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
    #expect(css.contains(
        "--habitat-readable-muted: color-mix(in srgb, var(--habitat-muted-text) 30%, var(--habitat-text))"
    ))
    #expect(css.contains("color: var(--habitat-readable-muted)"))
    #expect(!css.contains("\(profile.selectors.sidebar) > :last-child"))

    let homeSubtitle = try cssRuleBody(
        selector: "\(root)[data-codex-habitat-route=\"home\"] \(homeContent) p",
        in: css
    )
    #expect(homeSubtitle.contains("background-image: none"))
    #expect(homeSubtitle.contains("padding: 0"))
    #expect(homeSubtitle.contains("width: fit-content"))

    let sidebarAction = try cssRuleBody(
        selector: "\(root) \(profile.selectors.sidebar) :where(a, button, [role=\"button\"])",
        in: css
    )
    #expect(sidebarAction.contains("text-shadow:"))
    #expect(sidebarAction.contains("var(--habitat-surface)"))

    let taskParagraph = try cssRuleBody(
        selector: "\(root)[data-codex-habitat-route=\"task\"] \(profile.selectors.threadScroll) p",
        in: css
    )
    #expect(taskParagraph.contains("color: var(--habitat-text)"))
    #expect(!taskParagraph.contains("color: var(--habitat-muted-text)"))
    #expect(!taskParagraph.contains("color: var(--habitat-readable-muted)"))
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
    #expect(!baseArtwork.contains("var(--habitat-stage-scrim)"))
    #expect(baseOverlay.contains("var(--habitat-stage-scrim)"))
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
    #expect(css.contains("@media (max-width: 900px)"))
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
            && $0 != profile.selectors.homeContent
    }
    let recipes = HabitatThemeStyleFamily.allCases.map {
        ThemeCompiler.styleTreatment(for: $0, profile: profile)
    }

    for (family, recipe) in zip(HabitatThemeStyleFamily.allCases, recipes) {
        for selector in selectors {
            #expect(recipe.contains(selector), "\(family.rawValue) omits \(selector)")
        }
        for surface in [
            "shell", "sidebar", "header", "stage", "transcript", "request", "response",
            "inset-content", "floating-content", "home-actions", "composer",
            "selected-navigation", "fades-and-resize",
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
        #expect(
            rule.contains("color: var(--habitat-home-action-text)"),
            "\(family.rawValue) keeps accessible host action text"
        )
        #expect(rule.contains("background-color:"), "\(family.rawValue) has no action fill")
        #expect(rule.contains("border"), "\(family.rawValue) has no action structure")
        #expect(!rule.contains("backdrop-filter"), "\(family.rawValue) blurs a repeated action")
        return normalizedStyleRecipe(rule)
    }

    #expect(Set(rules).count >= 7)
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
    #expect(css.contains("--habitat-on-accent: #000000"))
    #expect(css.contains("color-scheme: dark"))

    let lowAlphaTextPalette = HabitatThemePalette(
        surface: "#101820FF",
        panel: "#182633FF",
        panelAlt: "#24384AFF",
        text: "#FFFFFF01",
        mutedText: "#A9BAC8FF",
        accent: "#000000FF",
        secondary: "#FF4F9AFF",
        highlight: "#FFE45CFF",
        attention: "#FFAA33FF",
        error: "#F04455FF"
    )
    let lowAlphaTextTheme = BridgeTheme(
        tokens: BridgeThemeTokens(palette: lowAlphaTextPalette),
        artBlobURL: nil
    )
    let lowAlphaCSS = try ThemeCompiler.bundled().compile(
        theme: lowAlphaTextTheme,
        profile: try #require(
            try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
        )
    )
    #expect(lowAlphaCSS.contains("--habitat-on-accent: #FFFFFF"))

    let translucentWinnerPalette = HabitatThemePalette(
        surface: "#000000FF",
        panel: "#182633FF",
        panelAlt: "#24384AFF",
        text: "#FFFFFF80",
        mutedText: "#A9BAC8FF",
        accent: "#000000FF",
        secondary: "#FF4F9AFF",
        highlight: "#FFE45CFF",
        attention: "#FFAA33FF",
        error: "#F04455FF"
    )
    let translucentWinnerCSS = try ThemeCompiler.bundled().compile(
        theme: BridgeTheme(
            tokens: BridgeThemeTokens(palette: translucentWinnerPalette),
            artBlobURL: nil
        ),
        profile: try #require(
            try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
        )
    )
    #expect(translucentWinnerCSS.contains("--habitat-on-accent: #808080"))

    let translucentAccentPalette = HabitatThemePalette(
        surface: "#000000FF",
        panel: "#FFFFFFFF",
        panelAlt: "#808080FF",
        text: "#FFFFFFFF",
        mutedText: "#A9BAC8FF",
        accent: "#FFFFFF01",
        secondary: "#FF4F9AFF",
        highlight: "#FFE45CFF",
        attention: "#FFAA33FF",
        error: "#F04455FF"
    )
    let translucentAccentCSS = try ThemeCompiler.bundled().compile(
        theme: BridgeTheme(
            tokens: BridgeThemeTokens(palette: translucentAccentPalette),
            artBlobURL: nil
        ),
        profile: try #require(
            try CompatibilityProfileStore.bundled().profile(forVersion: "26.707.91948")
        )
    )
    #expect(translucentAccentCSS.contains("--habitat-submit-accent: #FFFFFF"))
    #expect(translucentAccentCSS.contains("--habitat-on-accent: #000000"))
    #expect(translucentAccentCSS.contains("background-color: var(--habitat-submit-accent)"))
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

private func cssDeclarationValue(_ property: String, in body: String) throws -> String {
    let expression = try NSRegularExpression(
        pattern: NSRegularExpression.escapedPattern(for: property) + #"\s*:\s*([^;]+)"#
    )
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    let match = try #require(expression.firstMatch(in: body, range: range))
    let valueRange = try #require(Range(match.range(at: 1), in: body))
    return String(body[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
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

private func cssNumber(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(value)
}

private func cssLineStyle(_ style: HabitatThemeSurfaceLineStyle) -> String {
    switch style {
    case .solid: "solid"
    case .dashed: "dashed"
    case .double: "double"
    case .raised: "outset"
    }
}

private func cssFocusStyle(_ style: HabitatThemeSurfaceFocusStyle) -> String {
    switch style {
    case .standard: "auto"
    case .solid: "solid"
    case .dotted: "dotted"
    case .double: "double"
    }
}

private func topLevelCommaCount(in value: String) -> Int {
    var depth = 0
    var count = 0
    for character in value {
        switch character {
        case "(": depth += 1
        case ")": depth = max(0, depth - 1)
        case "," where depth == 0: count += 1
        default: break
        }
    }
    return count
}

private func cssPixelLengths(in value: String) throws -> [Double] {
    let expression = try NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)px"#)
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return expression.matches(in: value, range: range).compactMap { match in
        guard let valueRange = Range(match.range(at: 1), in: value) else { return nil }
        return Double(value[valueRange])
    }
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
