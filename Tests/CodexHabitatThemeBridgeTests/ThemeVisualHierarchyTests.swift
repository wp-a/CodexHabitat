import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Suite
struct ThemeVisualHierarchyTests {
    private let homeActionFillPercent = 68
    private let selectedNavigationFillPercent = 64
    private let sidebarHoverFillPercent = 54

    @Test
    func builtInComposerMaterialsStayWithinTheRefinedRange() throws {
        #expect(BuiltInThemeCatalog.all.count == 24)
        #expect(Set(BuiltInThemeCatalog.all.map(\.styleFamily)).count == 9)

        for definition in BuiltInThemeCatalog.all {
            let opacity = definition.appearance(
                background: "background.jpg"
            ).resolvedComposerOpacity
            #expect(
                (0.84...0.90).contains(opacity),
                "\(definition.id) composer opacity is \(opacity)"
            )
        }
    }

    @Test
    func homeContainerCleanupIsRouteScopedAndPreservesHostFocusChrome() throws {
        let profile = try hierarchyProfile()
        let homeContent = try #require(profile.selectors.homeContent)
        let suggestions = try #require(profile.selectors.homeSuggestions)
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let homeRoot = "\(root)[data-codex-habitat-route=\"home\"]"
        let treatment = ThemeCompiler.surfaceTreatment(profile: profile)
        let content = try hierarchyRuleBody(selector: "\(homeRoot) \(homeContent)", in: treatment)
        let suggestionGroup = try hierarchyRuleBody(
            selector: "\(homeRoot) \(suggestions)",
            in: treatment
        )

        #expect(hierarchyRuleBodies(selector: "\(root) \(homeContent)", in: treatment).isEmpty)
        for (surface, body) in [("home content", content), ("suggestions", suggestionGroup)] {
            #expect(body.contains("background: transparent"), "\(surface) is not transparent")
            #expect(body.contains("backdrop-filter: none"), "\(surface) keeps a backdrop")
            #expect(!body.contains("outline:"), "\(surface) suppresses host focus outlines")
            #expect(!body.contains("border"), "\(surface) suppresses host borders")
            #expect(!body.contains("box-shadow"), "\(surface) suppresses host focus shadows")
        }
    }

    @Test
    func publicComposerOpacityUpperBoundRemainsBackwardCompatible() throws {
        let profile = try hierarchyProfile()
        let appearance = HabitatThemeAppearance(
            category: .custom,
            styleFamily: .cozyWorld,
            background: "background.jpg",
            artFocus: HabitatThemeFocalPoint(x: 0.5, y: 0.5),
            safeSide: .center,
            backgroundStrength: 0.42,
            panelOpacity: 0.88,
            blurRadius: 8,
            density: .comfortable,
            composerOpacity: 1.0
        )
        let theme = BridgeTheme(
            tokens: .workbench,
            appearance: BridgeThemeAppearance(appearance),
            artBlobURL: nil
        )

        let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)

        #expect(css.contains("--habitat-composer-opacity: 100%"))
    }

    @Test
    func compiledThemesUseAQuietSemanticActionAndNavigationHierarchy() throws {
        let profile = try hierarchyProfile()
        let suggestions = try #require(profile.selectors.homeSuggestions)
        let selectedNavigation = try #require(profile.selectors.selectedNavigation)
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let actionSelector = "\(root) \(suggestions) :where(button, [role=\"button\"])"
        let selectedSelector = "\(root) \(selectedNavigation)"
        let hoverSelector = "\(root) \(profile.selectors.sidebar) :where(a, button, [role=\"button\"]):not([aria-current]):not([aria-selected=\"true\"]):not([aria-pressed=\"true\"]):hover"

        #expect(selectedNavigationFillPercent > sidebarHoverFillPercent)

        for definition in BuiltInThemeCatalog.all {
            let css = try compiledCSS(for: definition, profile: profile)
            let action = try #require(
                hierarchyRuleBodies(selector: actionSelector, in: css).first {
                    $0.contains("background-color:")
                }
            )
            let selected = try #require(
                hierarchyRuleBodies(selector: selectedSelector, in: css).last {
                    $0.contains("background-color:")
                }
            )
            let hover = try #require(
                hierarchyRuleBodies(selector: hoverSelector, in: css).first {
                    $0.contains("background-color:")
                }
            )

            #expect(
                action.contains(
                    "var(--habitat-panel-alt) \(homeActionFillPercent)%, transparent"
                ),
                "\(definition.id) home action is not the lighter semantic material"
            )
            #expect(
                selected.contains(
                    "var(--habitat-panel-alt) \(selectedNavigationFillPercent)%, transparent"
                ),
                "\(definition.id) selected navigation is too opaque"
            )
            #expect(
                hover.contains(
                    "var(--habitat-panel-alt) \(sidebarHoverFillPercent)%, transparent"
                ),
                "\(definition.id) sidebar hover contract changed"
            )
        }
    }

    @Test
    func sharedRefinedShellUsesOneQuietIdleBoundaryPerSurface() throws {
        let profile = try hierarchyProfile()
        let suggestions = try #require(profile.selectors.homeSuggestions)
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let actionSelector = "\(root) \(suggestions) :where(button, [role=\"button\"])"
        let composerSelector = "\(root) \(profile.selectors.composer)"
        let sidebarSelector = "\(root) \(profile.selectors.sidebar)"
        let stageSelector = "\(root) \(profile.selectors.mainSurface)"

        for family in HabitatThemeStyleFamily.allCases {
            let treatment = ThemeCompiler.styleTreatment(for: family, profile: profile)
            let action = try hierarchyRuleBody(selector: actionSelector, in: treatment)
            let composer = try hierarchyRuleBody(selector: composerSelector, in: treatment)
            let sidebar = try hierarchyRuleBody(selector: sidebarSelector, in: treatment)
            let stage = try hierarchyRuleBody(selector: stageSelector, in: treatment)

            #expect(
                action.contains(
                    "border: 1px solid color-mix(in srgb, var(--habitat-accent) 34%, transparent)"
                ),
                "\(family.rawValue) does not use the shared quiet idle action boundary"
            )
            #expect(
                hierarchyPropertyCount("border", in: action) == 1,
                "\(family.rawValue) stacks multiple idle action borders"
            )
            #expect(!action.contains("outline:"), "\(family.rawValue) adds an idle action outline")
            #expect(!composer.contains("0 0 0 2px"), "\(family.rawValue) adds an idle composer halo")
            #expect(!composer.contains("border-left-width: 4px"), "\(family.rawValue) adds an idle composer rail")
            #expect(!composer.contains("border-top-width: 3px"), "\(family.rawValue) adds an idle composer rail")
            #expect(
                !sidebar.contains("border-right") && !sidebar.contains("inset -"),
                "\(family.rawValue) owns the shared sidebar edge"
            )
            #expect(
                !stage.contains("border-inline-start") && !stage.contains("inset 8px 0"),
                "\(family.rawValue) owns the shared stage edge"
            )
        }
    }

    @Test
    func gameCinematicCardsUseFineTintedBoundariesAndShortShadows() throws {
        let profile = try hierarchyProfile()
        let suggestions = try #require(profile.selectors.homeSuggestions)
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let treatment = ThemeCompiler.styleTreatment(for: .gameCinematic, profile: profile)
        let action = try hierarchyRuleBody(
            selector: "\(root) \(suggestions) :where(button, [role=\"button\"])",
            in: treatment
        )
        let composer = try hierarchyRuleBody(
            selector: "\(root) \(profile.selectors.composer)",
            in: treatment
        )

        for (surface, body) in [("home action", action), ("composer", composer)] {
            #expect(body.contains("border: 1px solid color-mix(in srgb"), "\(surface) lacks a fine tinted border")
            #expect(body.contains("var(--habitat-accent)"), "\(surface) border is not theme-derived")
            #expect(body.contains("var(--habitat-highlight)"), "\(surface) lacks an inner highlight")
            #expect(body.contains("inset 0 1px 0"), "\(surface) lacks an inner highlight")
            #expect(!body.contains("3px solid var(--habitat-attention)"), "\(surface) keeps the attention rail")
            #expect(!body.contains("30px"), "\(surface) keeps the long cinematic shadow")
            #expect(try hierarchyBorderRadius(in: body) <= 8)
            #expect(try hierarchyLongestShadowLength(in: body) <= 20)
        }
    }

    @Test
    func compiledComposerFocusShadowsRemainRestrained() throws {
        let profile = try hierarchyProfile()
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let selector = "\(root) \(profile.selectors.composer):focus-within"

        for definition in BuiltInThemeCatalog.all {
            let css = try compiledCSS(for: definition, profile: profile)
            let finalFocusRule = try #require(
                hierarchyRuleBodies(containingSelector: selector, in: css).last {
                    $0.contains("box-shadow:")
                }
            )

            #expect(
                finalFocusRule.contains("border-color:"),
                "\(definition.id) loses composer focus feedback"
            )
            #expect(
                !finalFocusRule.contains("36px"),
                "\(definition.id) keeps the long composer focus shadow"
            )
            #expect(
                try hierarchyLongestShadowLength(in: finalFocusRule) <= 20,
                "\(definition.id) composer focus shadow exceeds 20px"
            )

            if definition.styleFamily == .gameCinematic {
                #expect(finalFocusRule.contains("box-shadow:"))
                #expect(try hierarchyLongestShadowLength(in: finalFocusRule) <= 20)
            }
        }
    }

    @Test
    func everyStyleFamilyKeepsADistinctMaterialSignature() throws {
        let profile = try hierarchyProfile()
        let suggestions = try #require(profile.selectors.homeSuggestions)
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let actionSelector = "\(root) \(suggestions) :where(button, [role=\"button\"])"
        let composerSelector = "\(root) \(profile.selectors.composer)"

        let signatures = try HabitatThemeStyleFamily.allCases.map { family in
            let treatment = ThemeCompiler.styleTreatment(for: family, profile: profile)
            return [
                try hierarchyRuleBody(selector: actionSelector, in: treatment),
                try hierarchyRuleBody(selector: composerSelector, in: treatment),
            ].joined(separator: "|")
        }

        #expect(signatures.count == 9)
        #expect(Set(signatures).count == 9)
    }

    @Test
    func completeHomeAndSidebarSurfacesRemainUnblurred() throws {
        let profile = try hierarchyProfile()
        let homeContent = try #require(profile.selectors.homeContent)
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let protectedSelectors = [
            "\(root) \(profile.selectors.sidebar)",
            "\(root)[data-codex-habitat-route=\"home\"] \(homeContent)",
        ]

        for definition in BuiltInThemeCatalog.all {
            let css = try compiledCSS(for: definition, profile: profile)
            for selector in protectedSelectors {
                let bodies = hierarchyRuleBodies(selector: selector, in: css)
                #expect(!bodies.isEmpty, "\(definition.id) omits \(selector)")
                for body in bodies {
                    #expect(!body.lowercased().contains("blur("), "\(definition.id) blurs \(selector)")
                }
            }
        }
    }

    @Test
    func bundledThemeManifestsRemainDataOnly() throws {
        let themeRoot = repositoryRoot()
            .appending(path: "Sources/CodexHabitatApp/Resources/Themes")
        let manifestURLs = try FileManager.default.contentsOfDirectory(
            at: themeRoot,
            includingPropertiesForKeys: nil
        )
            .map { $0.appending(path: "habitat.json") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .sorted { $0.path < $1.path }
        let forbiddenKeys: Set<String> = [
            "css", "javascript", "script", "selector", "selectors", "command", "commands",
            "executable", "url", "remoteurl", "person", "portrait", "brand", "trademark",
        ]

        #expect(manifestURLs.count == 24)
        for manifestURL in manifestURLs {
            let data = try Data(contentsOf: manifestURL)
            let object = try JSONSerialization.jsonObject(with: data)
            let keys = hierarchyJSONKeys(in: object).map { $0.lowercased() }
            let strings = hierarchyJSONStrings(in: object).map { $0.lowercased() }

            #expect(Set(keys).isDisjoint(with: forbiddenKeys), "\(manifestURL.lastPathComponent) contains executable fields")
            #expect(!strings.contains { $0.contains("http://") || $0.contains("https://") })
        }
    }
}

private func hierarchyProfile() throws -> CompatibilityProfile {
    try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
}

private func compiledCSS(
    for definition: BuiltInThemeDefinition,
    profile: CompatibilityProfile
) throws -> String {
    let theme = BridgeTheme(
        tokens: BridgeThemeTokens(palette: definition.palette),
        appearance: BridgeThemeAppearance(definition.appearance(background: "background.jpg")),
        artBlobURL: nil
    )
    return try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
}

private func hierarchyRuleBody(selector: String, in css: String) throws -> String {
    try #require(hierarchyRuleBodies(selector: selector, in: css).first)
}

private func hierarchyRuleBodies(selector: String, in css: String) -> [String] {
    let escaped = NSRegularExpression.escapedPattern(for: selector)
    guard let expression = try? NSRegularExpression(
        pattern: escaped + #"\s*\{([^}]*)\}"#,
        options: .dotMatchesLineSeparators
    ) else { return [] }
    let range = NSRange(css.startIndex..<css.endIndex, in: css)
    return expression.matches(in: css, range: range).compactMap { match in
        guard let bodyRange = Range(match.range(at: 1), in: css) else { return nil }
        return String(css[bodyRange])
    }
}

private func hierarchyRuleBodies(containingSelector selector: String, in css: String) -> [String] {
    let escaped = NSRegularExpression.escapedPattern(for: selector)
    guard let expression = try? NSRegularExpression(
        pattern: escaped + #"(?:\s*,[^{}]*)?\s*\{([^}]*)\}"#,
        options: .dotMatchesLineSeparators
    ) else { return [] }
    let range = NSRange(css.startIndex..<css.endIndex, in: css)
    return expression.matches(in: css, range: range).compactMap { match in
        guard let bodyRange = Range(match.range(at: 1), in: css) else { return nil }
        return String(css[bodyRange])
    }
}

private func hierarchyPropertyCount(_ property: String, in body: String) -> Int {
    body.components(separatedBy: "\(property):").count - 1
}

private func hierarchyBorderRadius(in body: String) throws -> Double {
    let expression = try NSRegularExpression(pattern: #"border-radius:\s*([0-9]+(?:\.[0-9]+)?)px"#)
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    let match = try #require(expression.firstMatch(in: body, range: range))
    let valueRange = try #require(Range(match.range(at: 1), in: body))
    return try #require(Double(body[valueRange]))
}

private func hierarchyLongestShadowLength(in body: String) throws -> Double {
    let shadow = try #require(
        body.range(of: #"box-shadow:\s*([^;]+)"#, options: .regularExpression)
    )
    let value = String(body[shadow])
    let expression = try NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)px"#)
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let lengths = expression.matches(in: value, range: range).compactMap { match -> Double? in
        guard let valueRange = Range(match.range(at: 1), in: value) else { return nil }
        return Double(value[valueRange])
    }
    return try #require(lengths.max())
}

private func hierarchyJSONKeys(in value: Any) -> [String] {
    if let dictionary = value as? [String: Any] {
        return Array(dictionary.keys) + dictionary.values.flatMap(hierarchyJSONKeys)
    }
    if let array = value as? [Any] {
        return array.flatMap(hierarchyJSONKeys)
    }
    return []
}

private func hierarchyJSONStrings(in value: Any) -> [String] {
    if let string = value as? String { return [string] }
    if let dictionary = value as? [String: Any] {
        return dictionary.values.flatMap(hierarchyJSONStrings)
    }
    if let array = value as? [Any] {
        return array.flatMap(hierarchyJSONStrings)
    }
    return []
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
