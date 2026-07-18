import Foundation
import HabitatCore

struct BridgeThemeTokens: Codable, Equatable, Sendable {
    let surface: String
    let panel: String
    let panelAlt: String
    let text: String
    let mutedText: String
    let accent: String
    let secondary: String
    let highlight: String
    let attention: String
    let error: String

    init(palette: HabitatThemePalette) {
        surface = palette.surface
        panel = palette.panel
        panelAlt = palette.panelAlt
        text = palette.text
        mutedText = palette.mutedText
        accent = palette.accent
        secondary = palette.secondary
        highlight = palette.highlight
        attention = palette.attention
        error = palette.error
    }

    static let workbench = BridgeThemeTokens(
        palette: BuiltInThemeCatalog.definition(id: "workbench")!.palette
    )
}

struct BridgeThemeAppearance: Codable, Equatable, Sendable {
    let styleFamily: HabitatThemeStyleFamily
    let artFocus: HabitatThemeFocalPoint
    let safeSide: HabitatThemeSafeSide
    let backgroundStrength: Double
    let panelOpacity: Double
    let blurRadius: Double
    let density: HabitatThemeDensity
    let homeMode: HabitatThemeHomeMode
    let taskMode: HabitatThemeTaskMode
    let chromeMaterial: HabitatThemeChromeMaterial
    let homeStrength: Double
    let taskStrength: Double
    let sidebarOpacity: Double
    let headerOpacity: Double
    let composerOpacity: Double

    init(_ appearance: HabitatThemeAppearance) {
        styleFamily = appearance.styleFamily
        artFocus = appearance.artFocus
        safeSide = appearance.safeSide
        backgroundStrength = appearance.backgroundStrength
        panelOpacity = appearance.panelOpacity
        blurRadius = appearance.blurRadius
        density = appearance.density
        homeMode = appearance.resolvedHomeMode
        taskMode = appearance.resolvedTaskMode
        chromeMaterial = appearance.resolvedChromeMaterial
        homeStrength = appearance.resolvedHomeStrength
        taskStrength = appearance.resolvedTaskStrength
        sidebarOpacity = appearance.resolvedSidebarOpacity
        headerOpacity = appearance.resolvedHeaderOpacity
        composerOpacity = appearance.resolvedComposerOpacity
    }

    static let workbench = BridgeThemeAppearance(
        BuiltInThemeCatalog.definition(id: "workbench")!.appearance(background: "background.jpg")
    )
}

struct BridgeTheme: Codable, Equatable, Sendable {
    let tokens: BridgeThemeTokens
    let appearance: BridgeThemeAppearance
    let artBlobURL: String?
    let artDataURL: String?

    init(
        tokens: BridgeThemeTokens,
        appearance: BridgeThemeAppearance = .workbench,
        artBlobURL: String?,
        artDataURL: String? = nil
    ) {
        self.tokens = tokens
        self.appearance = appearance
        self.artBlobURL = artBlobURL
        self.artDataURL = artDataURL
    }
}

extension BridgeTheme {
    static func builtIn(id: String) -> BridgeTheme? {
        guard let definition = BuiltInThemeCatalog.definition(id: id) else { return nil }
        return BridgeTheme(
            tokens: BridgeThemeTokens(palette: definition.palette),
            appearance: BridgeThemeAppearance(definition.appearance(background: "background.jpg")),
            artBlobURL: nil,
            artDataURL: builtInArtDataURL(id: id)
        )
    }

    private static func builtInArtDataURL(id: String) -> String? {
        let subdirectory = "Resources/Themes/\(id)"
        guard let url = PackagedResourceLocator.url(
            forResource: "background",
            withExtension: "jpg",
            subdirectory: subdirectory,
            packageBundleName: "CodexHabitat_CodexHabitatApp.bundle"
        ), let data = try? Data(contentsOf: url, options: .mappedIfSafe)
        else {
            return nil
        }
        return BridgeThemeArt.dataURL(data: data, pathExtension: "jpg")
    }
}

enum ThemeCompilationError: Error, Equatable {
    case unknownThemeField(String)
    case invalidColorToken(String)
    case invalidAppearance(String)
    case invalidArtBlobURL
    case invalidArtDataURL
    case unsafeTemplate
    case missingPlaceholder(String)
}

struct BridgeThemeDecoder {
    func decode(_ data: Data) throws -> BridgeTheme {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ThemeCompilationError.unknownThemeField("document")
        }
        try rejectUnknownFields(
            in: object,
            allowed: ["tokens", "appearance", "artBlobURL", "artDataURL"],
            prefix: ""
        )
        if let tokens = object["tokens"] as? [String: Any] {
            try rejectUnknownFields(
                in: tokens,
                allowed: [
                    "surface", "panel", "panelAlt", "text", "mutedText", "accent",
                    "secondary", "highlight", "attention", "error",
                ],
                prefix: "tokens."
            )
        }
        if let appearance = object["appearance"] as? [String: Any] {
            try rejectUnknownFields(
                in: appearance,
                allowed: [
                    "styleFamily", "artFocus", "safeSide", "backgroundStrength",
                    "panelOpacity", "blurRadius", "density",
                    "homeMode", "taskMode", "chromeMaterial", "homeStrength",
                    "taskStrength", "sidebarOpacity", "headerOpacity", "composerOpacity",
                ],
                prefix: "appearance."
            )
            if let artFocus = appearance["artFocus"] as? [String: Any] {
                try rejectUnknownFields(
                    in: artFocus,
                    allowed: ["x", "y"],
                    prefix: "appearance.artFocus."
                )
            }
        }
        return try JSONDecoder().decode(BridgeTheme.self, from: data)
    }

    private func rejectUnknownFields(
        in object: [String: Any],
        allowed: Set<String>,
        prefix: String
    ) throws {
        let unknown = Set(object.keys).subtracting(allowed)
        if prefix.isEmpty, unknown.contains("selectors") {
            throw ThemeCompilationError.unknownThemeField("selectors")
        }
        if let field = unknown.sorted().first {
            throw ThemeCompilationError.unknownThemeField(prefix + field)
        }
    }
}

struct ThemeCompiler {
    private let template: String

    init(template: String) throws {
        let lowered = template.lowercased()
        guard !lowered.contains("@import"),
              !lowered.contains("http://"),
              !lowered.contains("https://"),
              !lowered.contains("javascript:")
        else {
            throw ThemeCompilationError.unsafeTemplate
        }
        self.template = template
    }

    static func bundled() throws -> ThemeCompiler {
        guard let url = PackagedResourceLocator.url(
            forResource: "codex-theme-template",
            withExtension: "css",
            subdirectory: "Resources",
            packageBundleName: "CodexHabitat_CodexHabitatThemeBridge.bundle"
        ) else {
            throw ThemeCompilationError.unsafeTemplate
        }
        return try ThemeCompiler(template: String(contentsOf: url, encoding: .utf8))
    }

    func compile(theme: BridgeTheme, profile: CompatibilityProfile) throws -> String {
        let colors: [(String, String)] = [
            ("surface", theme.tokens.surface),
            ("panel", theme.tokens.panel),
            ("panel-alt", theme.tokens.panelAlt),
            ("text", theme.tokens.text),
            ("muted-text", theme.tokens.mutedText),
            ("accent", theme.tokens.accent),
            ("secondary", theme.tokens.secondary),
            ("highlight", theme.tokens.highlight),
            ("attention", theme.tokens.attention),
            ("error", theme.tokens.error),
        ]
        for (name, color) in colors where color.range(
            of: "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$",
            options: .regularExpression
        ) == nil {
            throw ThemeCompilationError.invalidColorToken(name)
        }
        try validate(theme.appearance)

        let artBackground: String
        if theme.artBlobURL != nil, theme.artDataURL != nil {
            throw ThemeCompilationError.invalidArtDataURL
        } else if let artBlobURL = theme.artBlobURL {
            guard artBlobURL.range(
                of: "^blob:app://[A-Za-z0-9._/-]+$",
                options: .regularExpression
            ) != nil else {
                throw ThemeCompilationError.invalidArtBlobURL
            }
            artBackground = "url(\"\(artBlobURL)\")"
        } else if let artDataURL = theme.artDataURL {
            guard BridgeThemeArt.isValidDataURL(artDataURL) else {
                throw ThemeCompilationError.invalidArtDataURL
            }
            artBackground = "url(\"\(artDataURL)\")"
        } else {
            artBackground = "none"
        }

        let artX = Self.cssPercent(theme.appearance.artFocus.x * 100)
        let artY = Self.cssPercent(theme.appearance.artFocus.y * 100)
        let artVeil = Self.cssPercent((1 - theme.appearance.backgroundStrength) * 100)
        let routeVeil = Self.cssPercent((1 - theme.appearance.backgroundStrength * 0.46) * 100)
        let panelOpacity = Self.cssPercent(theme.appearance.panelOpacity * 100)
        let densitySpacing = theme.appearance.density == .compact ? "8px" : "12px"

        var result = template
        let replacements = [
            "surface": theme.tokens.surface,
            "panel": theme.tokens.panel,
            "panel-alt": theme.tokens.panelAlt,
            "text": theme.tokens.text,
            "muted-text": theme.tokens.mutedText,
            "accent": theme.tokens.accent,
            "secondary": theme.tokens.secondary,
            "highlight": theme.tokens.highlight,
            "attention": theme.tokens.attention,
            "error": theme.tokens.error,
            "color-scheme": Self.colorScheme(for: theme.tokens.surface),
            "art-background": artBackground,
            "art-position-x": artX,
            "art-position-y": artY,
            "art-veil": artVeil,
            "route-veil": routeVeil,
            "panel-opacity": panelOpacity,
            "home-strength": Self.cssPercent(theme.appearance.homeStrength * 100),
            "task-strength": Self.cssPercent(theme.appearance.taskStrength * 100),
            "home-veil": Self.cssPercent((1 - theme.appearance.homeStrength) * 100),
            "task-veil": Self.cssPercent((1 - theme.appearance.taskStrength) * 100),
            "sidebar-opacity": Self.cssPercent(theme.appearance.sidebarOpacity * 100),
            "header-opacity": Self.cssPercent(theme.appearance.headerOpacity * 100),
            "composer-opacity": Self.cssPercent(theme.appearance.composerOpacity * 100),
            "safe-scrim": Self.safeScrim(for: theme.appearance.safeSide),
            "blur-radius": Self.cssNumber(theme.appearance.blurRadius) + "px",
            "tinted-blur-radius": Self.cssNumber(theme.appearance.blurRadius * 0.55) + "px",
            "density-spacing": densitySpacing,
            "sidebar": profile.selectors.sidebar,
            "main": profile.selectors.mainSurface,
            "composer": profile.selectors.composer,
            "thread": profile.selectors.threadScroll,
            "popover": profile.selectors.popover,
            "header": profile.selectors.header,
            "home-treatment": Self.homeTreatment(
                for: theme.appearance.homeMode,
                profile: profile
            ),
            "task-treatment": Self.taskTreatment(
                for: theme.appearance.taskMode,
                profile: profile
            ),
            "chrome-treatment": Self.chromeTreatment(
                for: theme.appearance.chromeMaterial,
                profile: profile
            ),
            "style-treatment": Self.styleTreatment(
                for: theme.appearance.styleFamily,
                profile: profile
            ),
        ]
        for (name, value) in replacements {
            let placeholder = "{{\(name)}}"
            guard result.contains(placeholder) else {
                throw ThemeCompilationError.missingPlaceholder(name)
            }
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        guard !result.contains("{{") else {
            throw ThemeCompilationError.unsafeTemplate
        }
        return result
    }

    static func homeTreatment(
        for mode: HabitatThemeHomeMode,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"]"
        let body = "\(root) body"
        let main = "\(root) \(profile.selectors.mainSurface)"
        return switch mode {
        case .immersive:
            """
            /* habitat-home-mode: immersive */
            \(body) {
              background-image: var(--habitat-art-background);
              background-position: var(--habitat-art-position);
              background-repeat: no-repeat;
              background-size: cover;
            }
            \(main) {
              background-color: transparent;
              background-image: var(--habitat-safe-scrim), linear-gradient(color-mix(in srgb, var(--habitat-surface) var(--habitat-home-veil), transparent), color-mix(in srgb, var(--habitat-surface) var(--habitat-home-veil), transparent));
              border-radius: 0;
            }
            """
        case .framed:
            """
            /* habitat-home-mode: framed */
            \(main) {
              border: 1px solid color-mix(in srgb, var(--habitat-accent) 34%, transparent);
              border-right: 0;
              border-bottom: 0;
              border-radius: 16px 0 0 0;
              box-shadow: -10px 0 32px color-mix(in srgb, var(--habitat-surface) 26%, transparent);
            }
            """
        case .quiet:
            """
            /* habitat-home-mode: quiet */
            \(main) {
              border-radius: 10px 0 0 0;
              box-shadow: inset 0 1px 0 color-mix(in srgb, var(--habitat-text) 8%, transparent);
            }
            """
        }
    }

    static func taskTreatment(
        for mode: HabitatThemeTaskMode,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"task\"]"
        let body = "\(root) body"
        let main = "\(root) \(profile.selectors.mainSurface)"
        return switch mode {
        case .ambient:
            """
            /* habitat-task-mode: ambient */
            \(body) {
              background-image: var(--habitat-art-background);
              background-position: var(--habitat-art-position);
              background-repeat: no-repeat;
              background-size: cover;
            }
            \(main) {
              background-color: transparent;
              background-image: var(--habitat-safe-scrim), linear-gradient(color-mix(in srgb, var(--habitat-surface) var(--habitat-task-veil), transparent), color-mix(in srgb, var(--habitat-surface) var(--habitat-task-veil), transparent));
            }
            """
        case .banner:
            """
            /* habitat-task-mode: banner */
            \(main) {
              background-image: linear-gradient(to bottom, transparent 0 34%, var(--habitat-surface) 76% 100%), var(--habitat-safe-scrim), linear-gradient(color-mix(in srgb, var(--habitat-surface) var(--habitat-task-veil), transparent), color-mix(in srgb, var(--habitat-surface) var(--habitat-task-veil), transparent)), var(--habitat-art-background);
              background-position: center, center, center, var(--habitat-art-position);
              background-repeat: no-repeat;
              background-size: 100% 100%, 100% 100%, 100% 100%, cover;
            }
            """
        case .off:
            """
            /* habitat-task-mode: off */
            \(main) {
              background-color: var(--habitat-surface);
              background-image: none;
            }
            """
        }
    }

    static func chromeTreatment(
        for material: HabitatThemeChromeMaterial,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let selectors = [
            "\(root) \(profile.selectors.sidebar)",
            "\(root) \(profile.selectors.header)",
            "\(root) \(profile.selectors.composer)",
            "\(root) \(profile.selectors.popover)",
        ].joined(separator: ",\n")
        return switch material {
        case .solid:
            """
            /* habitat-chrome-material: solid */
            \(selectors) {
              backdrop-filter: none;
            }
            """
        case .tinted:
            """
            /* habitat-chrome-material: tinted */
            \(selectors) {
              backdrop-filter: blur(var(--habitat-tinted-blur-radius)) saturate(1.04);
            }
            """
        case .glass:
            """
            /* habitat-chrome-material: glass */
            \(selectors) {
              backdrop-filter: blur(var(--habitat-blur-radius)) saturate(1.16);
              box-shadow: inset 0 1px 0 color-mix(in srgb, white 34%, transparent), 0 12px 30px color-mix(in srgb, var(--habitat-surface) 18%, transparent);
            }
            """
        }
    }

    static func styleTreatment(
        for family: HabitatThemeStyleFamily,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let sidebar = "\(root) \(profile.selectors.sidebar)"
        let composer = "\(root) \(profile.selectors.composer)"
        let popover = "\(root) \(profile.selectors.popover)"
        let declarations: (sidebar: String, composer: String, popover: String) = switch family {
        case .arcade:
            (
                "border-right-width: 2px; box-shadow: inset -3px 0 0 var(--habitat-secondary);",
                "border-radius: 4px; box-shadow: 0 0 0 2px color-mix(in srgb, var(--habitat-highlight) 34%, transparent), 0 8px 24px color-mix(in srgb, var(--habitat-accent) 22%, transparent);",
                "border-radius: 4px; border-width: 2px;"
            )
        case .retroMessenger:
            (
                "border-right-width: 1px; box-shadow: inset -1px 0 0 color-mix(in srgb, white 58%, transparent), inset 0 34px 0 color-mix(in srgb, var(--habitat-secondary) 30%, transparent);",
                "border-radius: 6px; border-top-color: color-mix(in srgb, white 72%, var(--habitat-accent)); box-shadow: inset 0 1px 0 color-mix(in srgb, white 76%, transparent), 0 5px 14px color-mix(in srgb, var(--habitat-text) 14%, transparent);",
                "border-radius: 6px; box-shadow: inset 0 1px 0 color-mix(in srgb, white 70%, transparent);"
            )
        case .greenChat:
            (
                "border-right-width: 4px; border-right-color: var(--habitat-secondary); box-shadow: inset -1px 0 0 color-mix(in srgb, white 45%, transparent);",
                "border-radius: 5px; border-left-width: 4px; border-left-color: var(--habitat-accent); box-shadow: 0 4px 12px color-mix(in srgb, var(--habitat-text) 12%, transparent);",
                "border-radius: 5px; border-top-width: 3px; border-top-color: var(--habitat-secondary);"
            )
        case .classicDesktop:
            (
                "border-right: 2px outset var(--habitat-panel-alt); box-shadow: inset 1px 1px 0 white, inset -1px -1px 0 color-mix(in srgb, black 55%, transparent);",
                "border-radius: 0; border: 2px inset var(--habitat-panel-alt); box-shadow: none;",
                "border-radius: 0; border: 2px outset var(--habitat-panel-alt); box-shadow: 2px 2px 0 color-mix(in srgb, black 55%, transparent);"
            )
        case .gameCinematic:
            (
                "border-right-width: 2px; border-right-color: color-mix(in srgb, var(--habitat-attention) 62%, transparent); box-shadow: inset -8px 0 18px color-mix(in srgb, var(--habitat-text) 10%, transparent);",
                "border-radius: 3px; border-inline-start-width: 3px; border-inline-start-color: var(--habitat-attention); box-shadow: 0 12px 30px color-mix(in srgb, black 28%, transparent);",
                "border-radius: 3px; border-block-start-width: 2px; border-block-start-color: var(--habitat-highlight);"
            )
        case .cozyWorld:
            (
                "border-right-width: 1px; box-shadow: inset -6px 0 14px color-mix(in srgb, var(--habitat-secondary) 14%, transparent);",
                "border-radius: 8px; border-width: 1px; box-shadow: 0 7px 18px color-mix(in srgb, var(--habitat-text) 12%, transparent), inset 0 1px 0 color-mix(in srgb, white 35%, transparent);",
                "border-radius: 8px; box-shadow: 0 8px 22px color-mix(in srgb, var(--habitat-secondary) 16%, transparent);"
            )
        case .animeEnergy:
            (
                "border-right-width: 3px; border-right-color: var(--habitat-highlight); box-shadow: inset -9px 0 0 color-mix(in srgb, var(--habitat-accent) 18%, transparent);",
                "border-radius: 2px; border-top-width: 3px; border-bottom-width: 1px; border-top-color: var(--habitat-highlight); box-shadow: 7px 7px 0 color-mix(in srgb, var(--habitat-secondary) 20%, transparent);",
                "border-radius: 2px; border-left-width: 3px; border-left-color: var(--habitat-secondary);"
            )
        case .fantasyAdventure:
            (
                "border-right-width: 2px; border-right-color: color-mix(in srgb, var(--habitat-highlight) 58%, var(--habitat-accent)); box-shadow: inset -4px 0 12px color-mix(in srgb, var(--habitat-accent) 18%, transparent);",
                "border-radius: 7px; border-width: 2px; outline: 1px solid color-mix(in srgb, var(--habitat-highlight) 28%, transparent); outline-offset: 2px; box-shadow: inset 0 0 18px color-mix(in srgb, var(--habitat-secondary) 12%, transparent);",
                "border-radius: 7px; border-width: 2px; box-shadow: inset 0 0 14px color-mix(in srgb, var(--habitat-highlight) 10%, transparent);"
            )
        case .pixelWorld:
            (
                "border-right-width: 3px; border-right-style: solid; box-shadow: inset -3px 0 0 color-mix(in srgb, black 42%, transparent); image-rendering: pixelated;",
                "border-radius: 0; border-width: 2px; box-shadow: 4px 4px 0 color-mix(in srgb, var(--habitat-text) 42%, transparent); image-rendering: pixelated;",
                "border-radius: 0; border-width: 2px; box-shadow: 3px 3px 0 color-mix(in srgb, var(--habitat-text) 38%, transparent);"
            )
        }
        return """
        /* habitat-style-family: \(family.rawValue) */
        \(sidebar) { \(declarations.sidebar) }
        \(composer) { \(declarations.composer) }
        \(popover) { \(declarations.popover) }
        """
    }

    private func validate(_ appearance: BridgeThemeAppearance) throws {
        guard appearance.artFocus.x.isFinite, (0...1).contains(appearance.artFocus.x),
              appearance.artFocus.y.isFinite, (0...1).contains(appearance.artFocus.y)
        else {
            throw ThemeCompilationError.invalidAppearance("artFocus")
        }
        guard appearance.backgroundStrength.isFinite,
              (0.10...0.70).contains(appearance.backgroundStrength)
        else {
            throw ThemeCompilationError.invalidAppearance("backgroundStrength")
        }
        guard appearance.panelOpacity.isFinite,
              (0.65...1.0).contains(appearance.panelOpacity)
        else {
            throw ThemeCompilationError.invalidAppearance("panelOpacity")
        }
        guard appearance.blurRadius.isFinite, (0...24).contains(appearance.blurRadius) else {
            throw ThemeCompilationError.invalidAppearance("blurRadius")
        }
        for (name, value) in [
            ("homeStrength", appearance.homeStrength),
            ("taskStrength", appearance.taskStrength),
        ] where !value.isFinite || !(0.10...0.85).contains(value) {
            throw ThemeCompilationError.invalidAppearance(name)
        }
        for (name, value) in [
            ("sidebarOpacity", appearance.sidebarOpacity),
            ("headerOpacity", appearance.headerOpacity),
            ("composerOpacity", appearance.composerOpacity),
        ] where !value.isFinite || !(0.40...1.0).contains(value) {
            throw ThemeCompilationError.invalidAppearance(name)
        }
    }

    private static func safeScrim(for safeSide: HabitatThemeSafeSide) -> String {
        switch safeSide {
        case .leading:
            "linear-gradient(to right, var(--habitat-surface) 0%, color-mix(in srgb, var(--habitat-surface) 88%, transparent) 38%, transparent 76%)"
        case .trailing:
            "linear-gradient(to left, var(--habitat-surface) 0%, color-mix(in srgb, var(--habitat-surface) 88%, transparent) 38%, transparent 76%)"
        case .center:
            "radial-gradient(ellipse at center, color-mix(in srgb, var(--habitat-surface) 90%, transparent) 0 24%, transparent 74%)"
        case .none:
            "linear-gradient(transparent, transparent)"
        }
    }

    private static func cssPercent(_ value: Double) -> String {
        cssNumber(value) + "%"
    }

    private static func cssNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.000_1 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    private static func colorScheme(for surface: String) -> String {
        let rgb = surface.dropFirst().prefix(6)
        let value = UInt64(rgb, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        return (0.2126 * red + 0.7152 * green + 0.0722 * blue) < 0.5
            ? "dark"
            : "light"
    }
}
