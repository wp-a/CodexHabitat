import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Test
func everyBundledThemePreservesCodexHomeGeometry() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
    let homeContent = try #require(profile.selectors.homeContent)
    let selectors = auditedHomeContentSelectors(homeContent)

    #expect(BuiltInThemeCatalog.all.count == 24)
    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
        for (index, selector) in selectors.enumerated() {
            let ruleDeclarations = try homeRuleDeclarations(selector: selector, in: css)
            if index == 0 {
                #expect(!ruleDeclarations.isEmpty, "\(definition.id) omits \(selector)")
            } else {
                #expect(ruleDeclarations.isEmpty, "\(definition.id) applies home cleanup outside home")
            }
            for declarations in ruleDeclarations {
                let geometry = declarations.filter(isHomeGeometryProperty).sorted()
                #expect(
                    geometry.isEmpty,
                    "\(definition.id) overrides \(selector) with \(geometry.joined(separator: ", "))"
                )
            }
        }
    }
}

@Test
func legacyHomeContentWidthDecodesWithoutChangingCompiledCSS() throws {
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
    let narrow = try BridgeThemeDecoder().decode(JSONEncoder().encode(homeWidthTheme(0.46)))
    let wide = try BridgeThemeDecoder().decode(JSONEncoder().encode(homeWidthTheme(0.68)))
    let compiler = try ThemeCompiler.bundled()
    let narrowCSS = try compiler.compile(theme: narrow, profile: profile)
    let wideCSS = try compiler.compile(theme: wide, profile: profile)

    #expect(narrow.appearance.homeContentWidth == 0.46)
    #expect(wide.appearance.homeContentWidth == 0.68)
    #expect(!narrowCSS.contains("--habitat-home-content-width"))
    #expect(narrowCSS == wideCSS)
}

@Test(arguments: [
    "width", "min-width", "max-width",
    "height", "min-height", "max-height",
    "inline-size", "min-inline-size", "max-inline-size",
    "block-size", "min-block-size", "max-block-size",
    "aspect-ratio", "contain-size",
    "margin", "margin-top", "margin-inline-start",
    "padding", "padding-left", "padding-block-end",
    "position", "inset", "inset-inline", "top", "right", "bottom", "left",
    "transform", "transform-origin", "translate", "display", "float",
    "grid", "grid-template-columns", "grid-column", "gap", "row-gap",
    "align-items", "justify-content", "place-self",
    "flex", "flex-basis", "flex-direction", "order",
])
func homeGeometryAuditRecognizesLayoutProperties(_ property: String) throws {
    let selector = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] main [role=\"main\"]"
    let css = "\(selector) { \(property): test-value; color: red; }"

    let declarations = try #require(homeRuleDeclarations(selector: selector, in: css).first)

    #expect(declarations.filter(isHomeGeometryProperty) == [property])
}

@Test
func homeGeometryAuditAllowsNonLayoutDeclarationsInsideMediaRules() throws {
    let selector = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] main [role=\"main\"]"
    let css = """
    @media (max-width: 900px) {
      \(selector) {
        color: red;
        background-color: transparent;
      }
    }
    """

    let declarations = try #require(homeRuleDeclarations(selector: selector, in: css).first)

    #expect(declarations.filter(isHomeGeometryProperty).isEmpty)
}

@Test
func homeGeometryAuditIncludesRouteNeutralGroupedRules() throws {
    let homeContent = "main [role=\"main\"]"
    let routeNeutral = "html[data-codex-habitat-theme=\"1\"] \(homeContent)"
    let css = """
    .unrelated-selector,
    \(routeNeutral) {
      max-inline-size: 44rem;
      color: red;
    }
    """

    let geometry = try auditedHomeContentSelectors(homeContent).flatMap { selector in
        try homeRuleDeclarations(selector: selector, in: css)
            .flatMap { $0.filter(isHomeGeometryProperty) }
    }

    #expect(geometry == ["max-inline-size"])
}

private func homeWidthTheme(_ width: Double) -> BridgeTheme {
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
        homeContentWidth: width
    )
    return BridgeTheme(
        tokens: .workbench,
        appearance: BridgeThemeAppearance(appearance),
        artBlobURL: nil
    )
}

private func auditedHomeContentSelectors(_ homeContent: String) -> [String] {
    [
        "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] \(homeContent)",
        "html[data-codex-habitat-theme=\"1\"] \(homeContent)",
    ]
}

private func homeRuleDeclarations(selector: String, in css: String) throws -> [[String]] {
    let expression = try NSRegularExpression(
        pattern: #"([^{}]+)\{([^{}]*)\}"#,
        options: .dotMatchesLineSeparators
    )
    let range = NSRange(css.startIndex..<css.endIndex, in: css)
    return expression.matches(in: css, range: range).compactMap { match in
        guard let selectorRange = Range(match.range(at: 1), in: css),
              let bodyRange = Range(match.range(at: 2), in: css)
        else { return nil }
        let selectors = String(css[selectorRange])
            .replacingOccurrences(
                of: #"/\*[\s\S]*?\*/"#,
                with: "",
                options: .regularExpression
            )
            .split(separator: ",")
            .map(normalizedSelector)
        guard selectors.contains(normalizedSelector(Substring(selector))) else { return nil }
        return declarationProperties(in: String(css[bodyRange]))
    }
}

private func declarationProperties(in body: String) -> [String] {
    body.split(separator: ";").compactMap { declaration in
        guard let colon = declaration.firstIndex(of: ":") else { return nil }
        return declaration[..<colon]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private func normalizedSelector(_ selector: Substring) -> String {
    String(selector)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func isHomeGeometryProperty(_ property: String) -> Bool {
    let exact: Set<String> = [
        "width", "min-width", "max-width",
        "height", "min-height", "max-height",
        "inline-size", "min-inline-size", "max-inline-size",
        "block-size", "min-block-size", "max-block-size",
        "aspect-ratio", "contain-size",
        "margin", "padding",
        "position", "inset", "top", "right", "bottom", "left",
        "transform", "translate", "display", "float",
        "grid", "flex", "gap", "row-gap", "column-gap", "order",
    ]
    if exact.contains(property) {
        return true
    }
    return [
        "margin-", "padding-", "inset-", "transform-", "translate-",
        "grid-", "flex-", "align-", "justify-", "place-",
    ].contains { property.hasPrefix($0) }
}
