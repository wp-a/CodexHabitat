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
    let selector = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] \(homeContent)"

    #expect(BuiltInThemeCatalog.all.count == 24)
    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
        let ruleBodies = try homeGeometryRuleBodies(selector: selector, in: css)

        #expect(!ruleBodies.isEmpty, "\(definition.id) omits the home content treatment")
        for body in ruleBodies {
            #expect(!body.contains("max-width"), "\(definition.id) constrains home width")
            #expect(!body.contains("margin-inline"), "\(definition.id) moves home content")
            #expect(!body.contains("translate"), "\(definition.id) translates home content")
        }
        for width in [1_180, 900] {
            let responsiveBodies = try homeGeometryMediaBodies(
                maxWidth: width,
                selector: selector,
                in: css
            )
            #expect(
                responsiveBodies.isEmpty,
                "\(definition.id) overrides the full home content at \(width)px"
            )
        }
    }
}

private func homeGeometryRuleBodies(selector: String, in css: String) throws -> [String] {
    let escaped = NSRegularExpression.escapedPattern(for: selector)
    let expression = try NSRegularExpression(
        pattern: escaped + #"\s*\{([^{}]*)\}"#,
        options: .dotMatchesLineSeparators
    )
    let range = NSRange(css.startIndex..<css.endIndex, in: css)
    return expression.matches(in: css, range: range).compactMap { match in
        guard let bodyRange = Range(match.range(at: 1), in: css) else { return nil }
        return String(css[bodyRange])
    }
}

private func homeGeometryMediaBodies(
    maxWidth: Int,
    selector: String,
    in css: String
) throws -> [String] {
    let marker = "@media (max-width: \(maxWidth)px)"
    var searchStart = css.startIndex
    var bodies: [String] = []

    while let markerRange = css.range(of: marker, range: searchStart..<css.endIndex),
          let openingBrace = css[markerRange.upperBound...].firstIndex(of: "{") {
        var depth = 1
        var cursor = css.index(after: openingBrace)
        while cursor < css.endIndex, depth > 0 {
            switch css[cursor] {
            case "{": depth += 1
            case "}": depth -= 1
            default: break
            }
            cursor = css.index(after: cursor)
        }
        guard depth == 0 else { break }
        let closingBrace = css.index(before: cursor)
        bodies += try homeGeometryRuleBodies(
            selector: selector,
            in: String(css[css.index(after: openingBrace)..<closingBrace])
        )
        searchStart = cursor
    }
    return bodies
}
