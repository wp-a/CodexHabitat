import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Suite
struct ThemeInteractionPolishTests {
    @Test
    func allTwentyFourThemesCompileTheNativeInteractionContract() throws {
        let profile = try completeInteractionProfile()

        #expect(BuiltInThemeCatalog.all.count == 24)
        #expect(
            Set(BuiltInThemeCatalog.all.map(\.styleFamily.rawValue))
                == Set(HabitatThemeStyleFamily.allCases.map(\.rawValue))
        )

        for definition in BuiltInThemeCatalog.all {
            let theme = BridgeTheme(
                tokens: BridgeThemeTokens(palette: definition.palette),
                appearance: BridgeThemeAppearance(
                    definition.appearance(background: "background.jpg")
                ),
                artBlobURL: nil
            )
            let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)

            try expectNativeInteractionContract(
                in: css,
                profile: profile,
                context: definition.id
            )
        }
    }

    @Test
    func everyStyleFamilyEmitsTheNativeInteractionContract() throws {
        let profile = try completeInteractionProfile()

        for family in HabitatThemeStyleFamily.allCases {
            try expectNativeInteractionContract(
                in: ThemeCompiler.styleTreatment(for: family, profile: profile),
                profile: profile,
                context: family.rawValue
            )
        }
    }

    @Test
    func interactionRulesUseScopedPropertyAllowlists() throws {
        let profile = try completeInteractionProfile()
        let styles = HabitatThemeStyleFamily.allCases.map {
            ThemeCompiler.styleTreatment(for: $0, profile: profile)
        }

        for (family, css) in zip(HabitatThemeStyleFamily.allCases, styles) {
            let rules = parseCSSRules(css)
            let stateRules = rules.filter { $0.isInteractionStateRule && !$0.isReducedMotionRule }
            let baseTransitionRules = rules.filter {
                !$0.isInteractionStateRule && !$0.isReducedMotionRule && $0.hasTransitionDeclaration
            }
            let reducedRules = rules.filter(\.isReducedMotionRule)

            #expect(!stateRules.isEmpty, "\(family.rawValue) has no interaction states")
            #expect(!baseTransitionRules.isEmpty, "\(family.rawValue) has no transition bases")
            #expect(!reducedRules.isEmpty, "\(family.rawValue) has no reduced-motion rule")

            for rule in stateRules {
                #expect(
                    interactionStateDeclarationsAreAllowed(rule.declarations),
                    "\(family.rawValue) state rule overrides native properties: \(rule.declarations.keys.sorted())"
                )
            }
            for rule in baseTransitionRules {
                #expect(
                    Set(rule.declarations.keys).isSubset(of: baseTransitionDeclarationAllowlist),
                    "\(family.rawValue) transition base mixes visual declarations"
                )
                #expect(rule.declarations["transition"] == nil, "\(family.rawValue) uses transition shorthand")
                let transitionedProperties = splitTopLevel(
                    rule.declarations["transition-property"] ?? "",
                    separator: ","
                ).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                #expect(
                    !transitionedProperties.isEmpty
                        && Set(transitionedProperties).isSubset(of: interactionStatePropertyAllowlist),
                    "\(family.rawValue) transitions unsupported properties: \(transitionedProperties)"
                )
                #expect(rule.declarations["transition-duration"] != nil)
                #expect(rule.declarations["transition-timing-function"] != nil)
            }
            for rule in reducedRules {
                #expect(
                    Set(rule.declarations.keys).isSubset(of: reducedMotionDeclarationAllowlist),
                    "\(family.rawValue) reduced motion overrides native properties"
                )
                #expect(
                    rule.declarations["transition"] == "none"
                        || rule.declarations["transition-duration"] == "0s",
                    "\(family.rawValue) does not disable interaction transitions"
                )
                #expect(rule.declarations["transform"] == nil)
            }
        }
    }

    @Test(arguments: [
        "border", "border-width", "font-size", "line-height", "transform", "width",
    ])
    func interactionStateAllowlistRejectsNativeAndLayoutProperties(_ property: String) {
        #expect(
            !interactionStateDeclarationsAreAllowed([property: "test-value"]),
            "state allowlist accepted \(property)"
        )
    }

    @Test(arguments: [
        "color", "background-color", "border-color", "box-shadow", "opacity",
    ])
    func interactionStateAllowlistAcceptsSemanticVisualProperties(_ property: String) {
        #expect(interactionStateDeclarationsAreAllowed([property: "test-value"]))
    }
}

private let interactionStatePropertyAllowlist: Set<String> = [
    "color", "background-color", "border-color", "box-shadow", "opacity",
]

private let baseTransitionDeclarationAllowlist: Set<String> = [
    "transition-property", "transition-duration", "transition-timing-function",
]

private let reducedMotionDeclarationAllowlist: Set<String> = [
    "transition", "transition-property", "transition-duration", "transition-timing-function",
]

private func interactionStateDeclarationsAreAllowed(_ declarations: [String: String]) -> Bool {
    !declarations.isEmpty
        && Set(declarations.keys).isSubset(of: interactionStatePropertyAllowlist)
}

private struct ParsedCSSRule {
    let selectors: [String]
    let declarations: [String: String]
    let mediaQueries: [String]

    var isInteractionStateRule: Bool {
        selectors.contains { selector in
            selector.contains(":hover")
                || selector.contains(":active")
                || selector.contains(":focus-within")
        }
    }

    var isReducedMotionRule: Bool {
        mediaQueries.contains { normalizedMedia($0).contains("prefers-reduced-motion:reduce") }
    }

    var hasTransitionDeclaration: Bool {
        declarations.keys.contains { property in
            property == "transition" || property.hasPrefix("transition-")
        }
    }
}

private func completeInteractionProfile() throws -> CompatibilityProfile {
    try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
}

private func expectNativeInteractionContract(
    in css: String,
    profile: CompatibilityProfile,
    context: String
) throws {
    let rules = parseCSSRules(css)
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let suggestions = try #require(profile.selectors.homeSuggestions)
    let homeAction = "\(root) \(suggestions) :where(button, [role=\"button\"])"
    let sidebarAction = "\(root) \(profile.selectors.sidebar) :where(a, button, [role=\"button\"])"

    let homeBase = try #require(transitionRule(for: homeAction, in: rules))
    #expect(homeBase.declarations["transition-property"] != nil, "\(context) lacks home transition")
    let homeHover = try #require(rules.first { rule in
        rule.selectors.contains("\(homeAction):hover") && isFinePointerHover(rule)
    })
    #expect(homeHover.declarations["background-color"] != nil, "\(context) lacks home hover fill")
    let homeActive = try #require(rule(for: "\(homeAction):active", in: rules))
    #expect(homeActive.declarations["opacity"] != nil, "\(context) lacks home press feedback")
    #expect(homeActive.declarations["background-color"] != nil, "\(context) lacks home press fill")

    let sidebarBase = try #require(rules.first { rule in
        rule.selectors.contains(sidebarAction)
            && rule.mediaQueries.isEmpty
            && rule.declarations["transition-property"] != nil
    })
    #expect(sidebarBase.declarations["transition-property"] != nil, "\(context) lacks sidebar transition")
    let sidebarInteractiveSelector = "\(sidebarAction):not([aria-current]):not([aria-selected=\"true\"]):not([aria-pressed=\"true\"])"
    let sidebarHoverSelector = "\(sidebarInteractiveSelector):hover"
    let sidebarActiveSelector = "\(sidebarInteractiveSelector):active"
    let sidebarHover = try #require(rules.first { rule in
        rule.selectors.contains { selector in
            selector == sidebarHoverSelector
        } && isFinePointerHover(rule)
    })
    #expect(
        sidebarHover.declarations["background-color"] != nil,
        "\(context) lacks sidebar hover fill"
    )
    #expect(
        rule(for: "\(sidebarAction):active", in: rules) == nil,
        "\(context) lets selected sidebar actions receive press feedback"
    )
    let sidebarActive = try #require(rule(for: sidebarActiveSelector, in: rules))
    #expect(sidebarActive.declarations["opacity"] != nil, "\(context) lacks sidebar press feedback")
    #expect(sidebarActive.declarations["background-color"] != nil, "\(context) lacks sidebar press fill")

    let composerSurfaces = [
        Optional(profile.selectors.composer),
        profile.selectors.composerContext,
    ].compactMap { $0 }
    for surface in composerSurfaces {
        let selector = "\(root) \(surface):focus-within"
        let focus = try #require(rule(for: selector, in: rules))
        #expect(focus.declarations["border-color"] != nil, "\(context) lacks composer focus border")
        #expect(focus.declarations["box-shadow"] != nil, "\(context) lacks composer focus shadow")
    }

    #expect(rule(for: "\(root) :focus-visible", in: rules) != nil, "\(context) removed keyboard focus")

    let reducedTargets = [
        homeAction,
        "\(homeAction):hover",
        "\(homeAction):active",
        sidebarAction,
        sidebarHoverSelector,
        sidebarActiveSelector,
    ] + composerSurfaces.flatMap { surface in
        ["\(root) \(surface)", "\(root) \(surface):focus-within"]
    }
    for target in reducedTargets {
        let reducedRule = try #require(rules.first { rule in
            rule.selectors.contains(target)
                && rule.mediaQueries.contains {
                    normalizedMedia($0).contains("prefers-reduced-motion:reduce")
                }
        })
        #expect(reducedRule.declarations["transition-duration"] == "0s", "\(context) keeps reduced motion")
        #expect(reducedRule.declarations["transform"] == nil, "\(context) clears a native transform")
    }
}

private func rule(for selector: String, in rules: [ParsedCSSRule]) -> ParsedCSSRule? {
    rules.first { $0.selectors.contains(selector) && $0.mediaQueries.isEmpty }
}

private func transitionRule(for selector: String, in rules: [ParsedCSSRule]) -> ParsedCSSRule? {
    rules.first {
        $0.selectors.contains(selector)
            && $0.mediaQueries.isEmpty
            && $0.declarations["transition-property"] != nil
    }
}

private func isFinePointerHover(_ rule: ParsedCSSRule) -> Bool {
    rule.mediaQueries.contains { query in
        let normalized = normalizedMedia(query)
        return normalized.contains("hover:hover") && normalized.contains("pointer:fine")
    }
}

private func normalizedMedia(_ query: String) -> String {
    query.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
}

private func parseCSSRules(_ css: String, mediaQueries: [String] = []) -> [ParsedCSSRule] {
    var rules: [ParsedCSSRule] = []
    var cursor = css.startIndex

    while cursor < css.endIndex {
        skipCSSWhitespaceAndComments(in: css, cursor: &cursor)
        guard cursor < css.endIndex else { break }
        let headerStart = cursor
        guard let openingBrace = nextOpeningBrace(in: css, from: cursor) else { break }
        let header = css[headerStart..<openingBrace].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let closingBrace = matchingBrace(in: css, openingBrace: openingBrace) else { break }
        let bodyStart = css.index(after: openingBrace)
        let body = String(css[bodyStart..<closingBrace])

        if header.hasPrefix("@media") {
            let query = header.dropFirst("@media".count).trimmingCharacters(in: .whitespacesAndNewlines)
            rules.append(contentsOf: parseCSSRules(body, mediaQueries: mediaQueries + [query]))
        } else if !header.hasPrefix("@") {
            rules.append(ParsedCSSRule(
                selectors: splitTopLevel(header, separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                },
                declarations: parseDeclarations(body),
                mediaQueries: mediaQueries
            ))
        }
        cursor = css.index(after: closingBrace)
    }
    return rules
}

private func parseDeclarations(_ body: String) -> [String: String] {
    var declarations: [String: String] = [:]
    for declaration in splitTopLevel(body, separator: ";") {
        guard let colon = declaration.firstIndex(of: ":") else { continue }
        let property = declaration[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = declaration[declaration.index(after: colon)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        declarations[property] = value
    }
    return declarations
}

private func splitTopLevel(_ value: String, separator: Character) -> [String] {
    var result: [String] = []
    var start = value.startIndex
    var cursor = value.startIndex
    var parentheses = 0
    var brackets = 0
    var quote: Character?

    while cursor < value.endIndex {
        let character = value[cursor]
        if let activeQuote = quote {
            if character == activeQuote && !isEscaped(in: value, at: cursor) { quote = nil }
        } else {
            switch character {
            case "\"", "'": quote = character
            case "(": parentheses += 1
            case ")": parentheses = max(0, parentheses - 1)
            case "[": brackets += 1
            case "]": brackets = max(0, brackets - 1)
            default:
                if character == separator && parentheses == 0 && brackets == 0 {
                    result.append(String(value[start..<cursor]))
                    start = value.index(after: cursor)
                }
            }
        }
        cursor = value.index(after: cursor)
    }
    result.append(String(value[start..<value.endIndex]))
    return result
}

private func nextOpeningBrace(in css: String, from start: String.Index) -> String.Index? {
    var cursor = start
    var quote: Character?
    while cursor < css.endIndex {
        let character = css[cursor]
        if let activeQuote = quote {
            if character == activeQuote && !isEscaped(in: css, at: cursor) { quote = nil }
        } else if character == "\"" || character == "'" {
            quote = character
        } else if character == "{" {
            return cursor
        }
        cursor = css.index(after: cursor)
    }
    return nil
}

private func matchingBrace(in css: String, openingBrace: String.Index) -> String.Index? {
    var cursor = css.index(after: openingBrace)
    var depth = 1
    var quote: Character?
    while cursor < css.endIndex {
        let character = css[cursor]
        if let activeQuote = quote {
            if character == activeQuote && !isEscaped(in: css, at: cursor) { quote = nil }
        } else {
            switch character {
            case "\"", "'": quote = character
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return cursor }
            default: break
            }
        }
        cursor = css.index(after: cursor)
    }
    return nil
}

private func skipCSSWhitespaceAndComments(in css: String, cursor: inout String.Index) {
    while cursor < css.endIndex {
        if css[cursor].isWhitespace {
            cursor = css.index(after: cursor)
            continue
        }
        guard css[cursor...].hasPrefix("/*"),
              let end = css[cursor...].range(of: "*/")?.upperBound
        else { return }
        cursor = end
    }
}

private func isEscaped(in value: String, at index: String.Index) -> Bool {
    guard index > value.startIndex else { return false }
    var cursor = value.index(before: index)
    var slashCount = 0
    while value[cursor] == "\\" {
        slashCount += 1
        guard cursor > value.startIndex else { break }
        cursor = value.index(before: cursor)
    }
    return slashCount.isMultiple(of: 2) == false
}
