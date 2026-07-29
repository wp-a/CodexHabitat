import Foundation
import HabitatCore
import Testing
@testable import CodexHabitatThemeBridge

@Test
func everyThemeKeepsTheSceneVisibleThroughRouteAwareSidebarWashes() throws {
    let compiler = try ThemeCompiler.bundled()
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
    let sidebar = profile.selectors.sidebar
    let root = "html[data-codex-habitat-theme=\"1\"]"
    let baseSelector = "\(root) \(sidebar)"
    let homeSelector = "\(root)[data-codex-habitat-route=\"home\"] \(sidebar)"
    let taskSelector = "\(root)[data-codex-habitat-route=\"task\"] \(sidebar)"

    #expect(BuiltInThemeCatalog.all.count == 24)

    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        let css = try compiler.compile(theme: theme, profile: profile)
        let rules = try parsedCSSRules(css)
        let baseRules = rules.filter { $0.selectors.contains(baseSelector) }
        let homeRules = rules.filter { $0.selectors.contains(homeSelector) }
        let taskRules = rules.filter { $0.selectors.contains(taskSelector) }
        let baseBackgroundRules = baseRules.filter(\.declaresBackground)
        let homeBackgroundRules = homeRules.filter(\.declaresBackground)
        let taskBackgroundRules = taskRules.filter(\.declaresBackground)
        let baseWash = try #require(baseRules.first { rule in
            rule.declarations["background-color"]?.contains(
                "var(--habitat-sidebar-chrome)"
            ) == true
        })
        let taskWash = try #require(taskRules.first { rule in
            rule.declarations["background-color"]?.contains(
                "var(--habitat-task-sidebar-chrome)"
            ) == true
        })

        #expect(
            baseBackgroundRules.count == 1,
            "\(definition.id) style treatment must not override the base sidebar wash"
        )
        #expect(
            taskBackgroundRules.count == 1,
            "\(definition.id) style treatment must not override the task sidebar wash"
        )
        for rule in homeBackgroundRules {
            let body = rule.body.lowercased()
            #expect(body.contains("var(--habitat-sidebar-chrome)"))
            #expect(!body.contains("var(--habitat-task-sidebar-chrome)"))
        }
        #expect(
            baseWash.declarations["background-image"] == "none",
            "\(definition.id) sidebar base must not add a directional color gradient"
        )
        #expect(
            baseWash.declarations["backdrop-filter"] == "none",
            "\(definition.id) sidebar base must not blur the scene"
        )
        #expect(
            baseWash.declarations["background-color"]?.contains(
                "var(--habitat-sidebar-chrome)"
            ) == true,
            "\(definition.id) home/base sidebar must use the home chrome material"
        )
        #expect(
            taskWash.declarations["background-image"] == "none",
            "\(definition.id) task sidebar must not add a directional color gradient"
        )
        #expect(
            taskWash.declarations["backdrop-filter"] == "none",
            "\(definition.id) task sidebar must not blur the scene"
        )
        #expect(
            taskWash.declarations["background-color"]?.contains(
                "var(--habitat-task-sidebar-chrome)"
            ) == true,
            "\(definition.id) task sidebar must use the stronger task chrome material"
        )

        for rule in baseRules + homeRules + taskRules {
            let body = rule.body.lowercased()
            #expect(!body.contains("blur("), "\(definition.id) sidebar must not blur")
            #expect(!body.contains("url("), "\(definition.id) sidebar must not repeat artwork")
            #expect(
                !body.contains("var(--habitat-art-background)"),
                "\(definition.id) sidebar must not consume the scene bitmap"
            )
            #expect(
                rule.declarations["background-image"] != nil
                    ? rule.declarations["background-image"] == "none"
                    : true,
                "\(definition.id) sidebar must not draw decorative image layers"
            )
        }
    }
}

@Test
func everyThemeKeepsOneFixedFullWindowArtworkConsumer() throws {
    let compiler = try ThemeCompiler.bundled()
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
    let shell = try #require(profile.selectors.appShell)
    let sceneSelector = "html[data-codex-habitat-theme=\"1\"] \(shell)::before"

    #expect(BuiltInThemeCatalog.all.count == 24)

    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        let css = try compiler.compile(theme: theme, profile: profile)
        let rules = try parsedCSSRules(css)
        let consumers = rules.filter { rule in
            rule.body.contains("var(--habitat-art-background)")
        }
        let scene = try #require(consumers.first)

        #expect(consumers.count == 1, "\(definition.id) must have one artwork consumer")
        #expect(scene.selectors == [sceneSelector])
        #expect(scene.declarations["position"] == "fixed")
        #expect(scene.declarations["inset"] == "0")
        #expect(scene.declarations["background-image"] == "var(--habitat-art-background)")
        let filter = try #require(scene.declarations["filter"])
        #expect(filter.contains("saturate(var(--habitat-art-saturation))"))
        #expect(filter.contains("contrast(var(--habitat-art-contrast))"))
        #expect(filter.contains("brightness(var(--habitat-art-exposure))"))
        #expect(
            occurrenceCount(of: "var(--habitat-art-background)", in: css) == 1,
            "\(definition.id) must not redraw the bitmap on another surface"
        )
    }
}

@Test
func everyThemeCompilesAStableRouteAwareMaterialHierarchy() throws {
    let compiler = try ThemeCompiler.bundled()
    let profile = try #require(
        try CompatibilityProfileStore.bundled().profile(forVersion: "26.715.31925")
    )
    let root = "html[data-codex-habitat-theme=\"1\"]"

    for definition in BuiltInThemeCatalog.all {
        let theme = try #require(BridgeTheme.builtIn(id: definition.id))
        let css = try compiler.compile(theme: theme, profile: profile)
        let rootRule = try #require(
            try parsedCSSRules(css).first { $0.selectors == [root] }
        )
        let declarations = rootRule.declarations
        let homeSidebar = try materialAlpha("--habitat-sidebar-chrome", in: declarations)
        let taskSidebar = try materialAlpha("--habitat-task-sidebar-chrome", in: declarations)
        let homeHeader = try materialAlpha("--habitat-header-chrome", in: declarations)
        let taskHeader = try materialAlpha("--habitat-task-header-chrome", in: declarations)
        let action = try materialAlpha("--habitat-action-fill", in: declarations)
        let composer = try materialAlpha("--habitat-composer-fill", in: declarations)

        #expect(homeSidebar > homeHeader, "\(definition.id) home sidebar is not stronger than its header")
        #expect(taskSidebar > taskHeader, "\(definition.id) task sidebar is not stronger than its header")
        #expect(taskSidebar >= homeSidebar, "\(definition.id) task sidebar regresses hierarchy")
        #expect(taskHeader >= homeHeader, "\(definition.id) task header regresses hierarchy")
        #expect(composer > action, "\(definition.id) composer is not stronger than home actions")
        if definition.treatment?.homeMode == .immersive {
            #expect(homeHeader <= 0.20, "\(definition.id) immersive home header is too opaque")
        }
    }
}

private struct ParsedCSSRule {
    let selectors: [String]
    let body: String
    let declarations: [String: String]

    var declaresBackground: Bool {
        declarations.keys.contains { property in
            property == "background" || property.hasPrefix("background-")
        }
    }
}

private func parsedCSSRules(_ css: String) throws -> [ParsedCSSRule] {
    let uncommented = css.replacingOccurrences(
        of: #"/\*[\s\S]*?\*/"#,
        with: "",
        options: .regularExpression
    )
    let expression = try NSRegularExpression(
        pattern: #"([^{}]+)\{([^{}]*)\}"#,
        options: .dotMatchesLineSeparators
    )
    let range = NSRange(uncommented.startIndex..<uncommented.endIndex, in: uncommented)
    return expression.matches(in: uncommented, range: range).compactMap { match in
        guard let selectorRange = Range(match.range(at: 1), in: uncommented),
              let bodyRange = Range(match.range(at: 2), in: uncommented)
        else { return nil }
        let body = String(uncommented[bodyRange])
        return ParsedCSSRule(
            selectors: uncommented[selectorRange]
                .split(separator: ",")
                .map(normalizedCSSSelector),
            body: body,
            declarations: parsedCSSDeclarations(body)
        )
    }
}

private func parsedCSSDeclarations(_ body: String) -> [String: String] {
    body.split(separator: ";").reduce(into: [:]) { declarations, rawDeclaration in
        guard let colon = rawDeclaration.firstIndex(of: ":") else { return }
        let property = rawDeclaration[..<colon]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let value = rawDeclaration[rawDeclaration.index(after: colon)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        declarations[property] = value
    }
}

private func normalizedCSSSelector(_ selector: Substring) -> String {
    String(selector)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func occurrenceCount(of needle: String, in haystack: String) -> Int {
    guard !needle.isEmpty else { return 0 }
    var count = 0
    var searchRange = haystack.startIndex..<haystack.endIndex
    while let range = haystack.range(of: needle, range: searchRange) {
        count += 1
        searchRange = range.upperBound..<haystack.endIndex
    }
    return count
}

private func materialAlpha(
    _ property: String,
    in declarations: [String: String]
) throws -> Double {
    let value = try #require(declarations[property])
    let expression = try NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)%"#)
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let match = try #require(expression.matches(in: value, range: range).last)
    let capture = try #require(Range(match.range(at: 1), in: value))
    return try #require(Double(value[capture])) / 100
}
