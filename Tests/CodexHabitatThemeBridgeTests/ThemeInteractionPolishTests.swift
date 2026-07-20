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
    func interactionRulesNeverMutateLayout() throws {
        let profile = try completeInteractionProfile()
        let styles = HabitatThemeStyleFamily.allCases.map {
            ThemeCompiler.styleTreatment(for: $0, profile: profile)
        }

        for (family, css) in zip(HabitatThemeStyleFamily.allCases, styles) {
            for rule in parseCSSRules(css).filter(\.isInteractionRule) {
                for (property, value) in rule.declarations {
                    #expect(
                        !isLayoutProperty(property, value: value),
                        "\(family.rawValue) interaction rule mutates layout with \(property)"
                    )
                    guard property == "transition" else { continue }
                    for item in splitTopLevel(value, separator: ",") {
                        let transitionedProperty = item
                            .split(whereSeparator: \.isWhitespace)
                            .first
                            .map(String.init) ?? ""
                        #expect(
                            transitionedProperty != "all",
                            "\(family.rawValue) uses transition: all"
                        )
                        #expect(
                            !isLayoutProperty(transitionedProperty, value: ""),
                            "\(family.rawValue) transitions layout property \(transitionedProperty)"
                        )
                    }
                }
            }
        }
    }
}

private struct ParsedCSSRule {
    let selectors: [String]
    let declarations: [String: String]
    let mediaQueries: [String]

    var isInteractionRule: Bool {
        selectors.contains { selector in
            selector.contains(":hover")
                || selector.contains(":active")
                || selector.contains(":focus-within")
                || selector.contains(":focus-visible")
        }
            || declarations["transition"] != nil
            || mediaQueries.contains { normalizedMedia($0).contains("prefers-reduced-motion:reduce") }
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

    let homeBase = try #require(rule(for: homeAction, in: rules))
    #expect(homeBase.declarations["transition"] != nil, "\(context) lacks home transition")
    let homeHover = try #require(rules.first { rule in
        rule.selectors.contains("\(homeAction):hover") && isFinePointerHover(rule)
    })
    #expect(homeHover.declarations["background-color"] != nil, "\(context) lacks home hover fill")
    let homeActive = try #require(rule(for: "\(homeAction):active", in: rules))
    #expect(homeActive.declarations["opacity"] != nil, "\(context) lacks home press feedback")

    let sidebarBase = try #require(rules.first { rule in
        rule.selectors.contains(sidebarAction)
            && rule.mediaQueries.isEmpty
            && rule.declarations["transition"] != nil
    })
    #expect(sidebarBase.declarations["transition"] != nil, "\(context) lacks sidebar transition")
    let sidebarHoverSelector = "\(sidebarAction):not([aria-current]):not([aria-selected=\"true\"]):not([aria-pressed=\"true\"]):hover"
    let sidebarHover = try #require(rules.first { rule in
        rule.selectors.contains { selector in
            selector == sidebarHoverSelector
        } && isFinePointerHover(rule)
    })
    #expect(
        sidebarHover.declarations["background-color"] != nil,
        "\(context) lacks sidebar hover fill"
    )
    let sidebarActive = try #require(rule(for: "\(sidebarAction):active", in: rules))
    #expect(sidebarActive.declarations["opacity"] != nil, "\(context) lacks sidebar press feedback")

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
        "\(sidebarAction):active",
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
        #expect(reducedRule.declarations["transition"] == "none", "\(context) keeps reduced motion")
        #expect(reducedRule.declarations["transform"] == "none", "\(context) keeps reduced transform")
    }
}

private func rule(for selector: String, in rules: [ParsedCSSRule]) -> ParsedCSSRule? {
    rules.first { $0.selectors.contains(selector) && $0.mediaQueries.isEmpty }
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

private func isLayoutProperty(_ property: String, value: String) -> Bool {
    let property = property.lowercased()
    let exact: Set<String> = [
        "width", "min-width", "max-width", "height", "min-height", "max-height",
        "inline-size", "min-inline-size", "max-inline-size",
        "block-size", "min-block-size", "max-block-size",
        "position", "top", "right", "bottom", "left", "display", "float",
        "aspect-ratio",
    ]
    if exact.contains(property) { return true }
    if property.hasPrefix("margin") || property.hasPrefix("padding") { return true }
    if property == "inset" || property.hasPrefix("inset-") { return true }
    if property == "grid" || property.hasPrefix("grid-") { return true }
    if property == "flex" || property.hasPrefix("flex-") { return true }
    if ["gap", "row-gap", "column-gap", "order"].contains(property) { return true }
    if property.hasPrefix("align-")
        || property.hasPrefix("justify-")
        || property.hasPrefix("place-") { return true }
    if property == "contain-size" || property == "contain-intrinsic-size" { return true }
    return property == "contain" && value.lowercased().split(whereSeparator: \.isWhitespace).contains("size")
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
