#if HABITAT_OFFLINE_FIXTURE
import CryptoKit
#endif
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
    let homeArtFocus: HabitatThemeFocalPoint
    let taskArtFocus: HabitatThemeFocalPoint
    let homeArtScale: Double
    let taskArtScale: Double
    let taskSidebarOpacity: Double
    let taskHeaderOpacity: Double
    let homeContentOpacity: Double
    let taskContentOpacity: Double
    let homeContentWidth: Double
    let vignetteStrength: Double

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
        homeArtFocus = appearance.resolvedHomeArtFocus
        taskArtFocus = appearance.resolvedTaskArtFocus
        homeArtScale = appearance.resolvedHomeArtScale
        taskArtScale = appearance.resolvedTaskArtScale
        taskSidebarOpacity = appearance.resolvedTaskSidebarOpacity
        taskHeaderOpacity = appearance.resolvedTaskHeaderOpacity
        homeContentOpacity = appearance.resolvedHomeContentOpacity
        taskContentOpacity = appearance.resolvedTaskContentOpacity
        homeContentWidth = appearance.resolvedHomeContentWidth
        vignetteStrength = appearance.resolvedVignetteStrength
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
                    "homeArtFocus", "taskArtFocus", "homeArtScale", "taskArtScale",
                    "taskSidebarOpacity", "taskHeaderOpacity", "homeContentOpacity",
                    "taskContentOpacity", "homeContentWidth", "vignetteStrength",
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
            for focusKey in ["homeArtFocus", "taskArtFocus"] {
                if let focus = appearance[focusKey] as? [String: Any] {
                    try rejectUnknownFields(
                        in: focus,
                        allowed: ["x", "y"],
                        prefix: "appearance.\(focusKey)."
                    )
                }
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

#if HABITAT_OFFLINE_FIXTURE
    var templateFingerprint: String {
        SHA256.hash(data: Data(template.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
#endif

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

        let densitySpacing = theme.appearance.density == .compact ? "8px" : "12px"
        let homeArtworkCrop = HabitatThemeArtworkCrop(
            focus: theme.appearance.homeArtFocus,
            scale: theme.appearance.homeArtScale
        )
        let taskArtworkCrop = HabitatThemeArtworkCrop(
            focus: theme.appearance.taskArtFocus,
            scale: theme.appearance.taskArtScale
        )

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
            "home-art-position-x": Self.cssPercent(homeArtworkCrop.focus.x * 100),
            "home-art-position-y": Self.cssPercent(homeArtworkCrop.focus.y * 100),
            "task-art-position-x": Self.cssPercent(taskArtworkCrop.focus.x * 100),
            "task-art-position-y": Self.cssPercent(taskArtworkCrop.focus.y * 100),
            "home-art-scale": Self.cssNumber(homeArtworkCrop.scale),
            "task-art-scale": Self.cssNumber(taskArtworkCrop.scale),
            "task-banner-art-inset": Self.cssPercent(Self.bannerArtworkBottomInset(
                focusY: taskArtworkCrop.focus.y,
                scale: taskArtworkCrop.scale
            ) * 100),
            "task-banner-fade-start": Self.cssPercent(Self.bannerArtworkLocalPosition(
                focusY: taskArtworkCrop.focus.y,
                scale: taskArtworkCrop.scale,
                transformedPosition: 0.46
            ) * 100),
            "task-banner-fade-end": Self.cssPercent(Self.bannerArtworkLocalPosition(
                focusY: taskArtworkCrop.focus.y,
                scale: taskArtworkCrop.scale,
                transformedPosition: 0.52
            ) * 100),
            "home-strength": Self.cssPercent(theme.appearance.homeStrength * 100),
            "task-strength": Self.cssPercent(theme.appearance.taskStrength * 100),
            "sidebar-opacity": Self.cssPercent(theme.appearance.sidebarOpacity * 100),
            "header-opacity": Self.cssPercent(theme.appearance.headerOpacity * 100),
            "composer-opacity": Self.cssPercent(theme.appearance.composerOpacity * 100),
            "task-sidebar-opacity": Self.cssPercent(
                theme.appearance.taskSidebarOpacity * 100
            ),
            "task-header-opacity": Self.cssPercent(theme.appearance.taskHeaderOpacity * 100),
            "home-content-opacity": Self.cssPercent(
                theme.appearance.homeContentOpacity * 100
            ),
            "task-content-opacity": Self.cssPercent(
                theme.appearance.taskContentOpacity * 100
            ),
            "vignette-strength": Self.cssPercent(theme.appearance.vignetteStrength * 100),
            "safe-scrim": Self.safeScrim(for: theme.appearance.safeSide),
            "task-reading-scrim": Self.taskReadingScrim(for: theme.appearance.safeSide),
            "blur-radius": Self.cssNumber(theme.appearance.blurRadius) + "px",
            "tinted-blur-radius": Self.cssNumber(theme.appearance.blurRadius * 0.55) + "px",
            "density-spacing": densitySpacing,
            "sidebar": profile.selectors.sidebar,
            "main": profile.selectors.mainSurface,
            "composer": profile.selectors.composer,
            "thread": profile.selectors.threadScroll,
            "popover": profile.selectors.popover,
            "header": profile.selectors.header,
            "app-shell": profile.selectors.appShell ?? "body",
            "surface-treatment": Self.surfaceTreatment(profile: profile),
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

    static func surfaceTreatment(profile: CompatibilityProfile) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"]"
        var rules: [String] = [
            """
            \(root) \(profile.selectors.sidebar) :where(a, button, [role="button"]) {
              color: var(--habitat-text);
            }
            \(root) \(profile.selectors.sidebar) :where(h1, h2, h3, h4, h5, h6) {
              color: var(--habitat-muted-text);
            }
            \(root)[data-codex-habitat-route="task"] \(profile.selectors.threadScroll) :where(h1, h2, h3, h4, h5, h6, strong) {
              color: var(--habitat-text);
            }
            \(root)[data-codex-habitat-route="task"] \(profile.selectors.threadScroll) p {
              color: var(--habitat-text);
            }
            """,
        ]

        if let homeContent = profile.selectors.homeContent {
            rules.append("""
            \(root)[data-codex-habitat-route="home"] \(homeContent) {
              background-color: color-mix(in srgb, var(--habitat-surface) var(--habitat-home-content-opacity), transparent);
              backdrop-filter: none;
            }
            \(root)[data-codex-habitat-route="home"] \(homeContent) p {
              color: var(--habitat-muted-text);
            }
            """)
        }
        if let suggestions = profile.selectors.homeSuggestions {
            rules.append("""
            \(root)[data-codex-habitat-route="home"] \(suggestions) {
              background-color: color-mix(in srgb, var(--habitat-panel) var(--habitat-home-content-opacity), transparent);
              border-color: color-mix(in srgb, var(--habitat-accent) 34%, transparent);
            }
            """)
        }
        if let transcript = profile.selectors.taskTranscript {
            rules.append("""
            \(root)[data-codex-habitat-route="task"] \(transcript) {
              background-color: transparent;
              background-image: none;
              backdrop-filter: none;
            }
            """)
        }
        if let userMessage = profile.selectors.userMessageSurface {
            rules.append("""
            \(root)[data-codex-habitat-route="task"] \(userMessage) {
              color: var(--habitat-text);
              background-color: color-mix(in srgb, var(--habitat-panel) 88%, transparent);
              border-color: color-mix(in srgb, var(--habitat-accent) 30%, transparent);
            }
            """)
        }
        if let message = profile.selectors.messageSurface {
            rules.append("""
            \(root)[data-codex-habitat-route="task"] \(message) {
              color: var(--habitat-text);
              background-color: color-mix(in srgb, var(--habitat-panel) var(--habitat-task-content-opacity), transparent);
            }
            """)
        }
        let protectedContent = [profile.selectors.codeSurface]
            .compactMap { $0 } + (profile.selectors.toolSurfaces ?? [])
        if !protectedContent.isEmpty {
            rules.append("""
            \(scopedSelectors(protectedContent, root: "\(root)[data-codex-habitat-route=\"task\"]")) {
              color: var(--habitat-text);
              background-color: color-mix(in srgb, var(--habitat-panel) 94%, transparent);
              border-color: color-mix(in srgb, var(--habitat-accent) 36%, transparent);
              backdrop-filter: none;
            }
            """)
        }
        if let selectedNavigation = profile.selectors.selectedNavigation {
            rules.append("""
            \(root) \(selectedNavigation) {
              background-color: color-mix(in srgb, var(--habitat-panel-alt) 78%, transparent);
              box-shadow: inset 3px 0 0 var(--habitat-accent);
            }
            """)
        }
        if let composerContext = profile.selectors.composerContext {
            rules.append("""
            \(root) \(composerContext) {
              background-color: color-mix(in srgb, var(--habitat-panel) var(--habitat-composer-opacity), transparent);
            }
            """)
        }
        let interruptionLayers = [
            profile.selectors.sidebarResizeChrome,
            profile.selectors.topFade,
            profile.selectors.bottomFade,
        ].compactMap { $0 }
        if !interruptionLayers.isEmpty {
            rules.append("""
            \(scopedSelectors(interruptionLayers, root: root)) {
              background: transparent;
              box-shadow: none;
              backdrop-filter: none;
            }
            """)
        }
        if let stickyBand = profile.selectors.stickyBand {
            rules.append("""
            \(root) \(stickyBand) {
              background-color: color-mix(in srgb, var(--habitat-panel) var(--habitat-task-content-opacity), transparent);
            }
            """)
        }
        return rules.joined(separator: "\n")
    }

    static func homeTreatment(
        for mode: HabitatThemeHomeMode,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"]"
        let appShell = profile.selectors.appShell ?? "body"
        let scene = "\(root) \(appShell)::before"
        let overlay = "\(root) \(appShell)::after"
        let main = "\(root) \(profile.selectors.mainSurface)"
        let header = "\(root) \(profile.selectors.header)"
        let immersiveHomeContent = profile.selectors.homeContent.map { homeContent in
            """
            \(root) \(homeContent) {
              background-color: transparent;
              background-image: none;
              backdrop-filter: none;
              box-shadow: none;
            }
            """
        } ?? ""
        return switch mode {
        case .immersive:
            """
            /* habitat-home-mode: immersive */
            \(scene) {
              inset: 0;
              opacity: var(--habitat-home-strength);
              background-position: var(--habitat-home-art-position);
              transform: scale(var(--habitat-home-art-scale));
              transform-origin: var(--habitat-home-art-position);
            }
            \(overlay) {
              inset: 0;
              opacity: 1;
              background-image: var(--habitat-safe-scrim);
              border: 0;
              border-radius: 0;
              box-shadow: none;
            }
            \(main) {
              background-color: transparent;
              background-image: none;
              border-radius: 0;
            }
            \(header) {
              background-color: transparent;
              background-image: none;
              border-bottom-color: transparent;
              backdrop-filter: none;
              box-shadow: none;
            }
            \(immersiveHomeContent)
            """
        case .framed:
            """
            /* habitat-home-mode: framed */
            \(scene) {
              inset: 0;
              opacity: var(--habitat-home-strength);
              background-position: var(--habitat-home-art-position);
              transform: scale(var(--habitat-home-art-scale));
              transform-origin: var(--habitat-home-art-position);
            }
            \(overlay) {
              inset: 16px;
              opacity: 1;
              background-image: var(--habitat-safe-scrim);
              border: 1px solid color-mix(in srgb, var(--habitat-accent) 42%, transparent);
              border-radius: 12px;
              box-shadow: 0 0 0 100vmax var(--habitat-surface), 0 14px 34px color-mix(in srgb, var(--habitat-surface) 24%, transparent);
            }
            \(main) {
              background-color: transparent;
              background-image: none;
              border-radius: 0;
            }
            """
        case .quiet:
            """
            /* habitat-home-mode: quiet */
            \(scene) {
              inset: 0;
              opacity: var(--habitat-home-strength);
              background-position: var(--habitat-home-art-position);
              transform: scale(var(--habitat-home-art-scale));
              transform-origin: var(--habitat-home-art-position);
            }
            \(overlay) {
              inset: 0;
              opacity: 1;
              background-image: var(--habitat-safe-scrim);
              border: 0;
              border-radius: 0;
              box-shadow: none;
            }
            \(main) {
              background-color: transparent;
              background-image: none;
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
        let appShell = profile.selectors.appShell ?? "body"
        let scene = "\(root) \(appShell)::before"
        let overlay = "\(root) \(appShell)::after"
        let main = "\(root) \(profile.selectors.mainSurface)"
        let readingSurfaces = [profile.selectors.threadScroll]
        func readingSurfaceRules(_ declarations: String) -> String {
            readingSurfaces.map { selector in
                """
                \(root) \(selector) {
                \(declarations)
                }
                """
            }.joined(separator: "\n")
        }
        return switch mode {
        case .ambient:
            """
            /* habitat-task-mode: ambient */
            \(scene) {
              inset: 0;
              opacity: var(--habitat-task-strength);
              background-position: var(--habitat-task-art-position);
              transform: scale(var(--habitat-task-art-scale));
              transform-origin: var(--habitat-task-art-position);
            }
            \(overlay) {
              inset: 0;
              opacity: 1;
              background-image: var(--habitat-safe-scrim);
              border: 0;
              border-radius: 0;
              box-shadow: none;
            }
            \(main) {
              background-color: transparent;
              background-image: none;
            }
            \(readingSurfaceRules("""
              background-color: transparent;
              background-image: var(--habitat-task-reading-scrim);
              background-repeat: no-repeat;
              background-size: 100% 100%;
              backdrop-filter: none;
            """))
            """
        case .banner:
            """
            /* habitat-task-mode: banner */
            \(scene) {
              inset: 0;
              opacity: var(--habitat-task-strength);
              background-position: var(--habitat-task-art-position);
              transform: scale(var(--habitat-task-art-scale));
              transform-origin: var(--habitat-task-art-position);
              clip-path: inset(0 0 var(--habitat-task-banner-art-inset) 0);
              -webkit-mask-image: linear-gradient(to bottom, black 0 var(--habitat-task-banner-fade-start), transparent var(--habitat-task-banner-fade-end));
              mask-image: linear-gradient(to bottom, black 0 var(--habitat-task-banner-fade-start), transparent var(--habitat-task-banner-fade-end));
            }
            \(overlay) {
              inset: 0;
              opacity: 1;
              background-image: var(--habitat-safe-scrim);
              border: 0;
              border-radius: 0;
              box-shadow: none;
              clip-path: inset(0 0 48% 0);
              -webkit-mask-image: linear-gradient(to bottom, black 0 46%, transparent 52%);
              mask-image: linear-gradient(to bottom, black 0 46%, transparent 52%);
            }
            \(main) {
              background-color: transparent;
              background-image: none;
            }
            \(readingSurfaceRules("""
              background-color: transparent;
              background-image: linear-gradient(to bottom, transparent 0 30%, color-mix(in srgb, var(--habitat-surface) 72%, transparent) 64%, color-mix(in srgb, var(--habitat-surface) 94%, transparent) 100%), var(--habitat-safe-scrim);
              background-repeat: no-repeat;
              background-size: 100% 100%;
              backdrop-filter: none;
            """))
            """
        case .off:
            """
            /* habitat-task-mode: off */
            \(scene) {
              opacity: 0;
              transform: none;
              clip-path: inset(0);
            }
            \(overlay) {
              inset: 0;
              opacity: 0;
              background-image: var(--habitat-safe-scrim);
              border: 0;
              border-radius: 0;
              box-shadow: none;
              clip-path: inset(0);
            }
            \(main) {
              background-color: color-mix(in srgb, var(--habitat-surface) 96%, transparent);
              background-image: none;
            }
            \(readingSurfaceRules("""
              background-color: color-mix(in srgb, var(--habitat-surface) 96%, transparent);
              background-image: none;
              backdrop-filter: none;
            """))
            """
        }
    }

    static func chromeTreatment(
        for material: HabitatThemeChromeMaterial,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"]"
        let sidebar = "\(root) \(profile.selectors.sidebar)"
        let smallChrome = [
            "\(root) \(profile.selectors.header)",
            "\(root) \(profile.selectors.composer)",
            "\(root) \(profile.selectors.popover)",
        ].joined(separator: ",\n")
        let treatment = switch material {
        case .solid:
            """
            /* habitat-chrome-material: solid */
            \(sidebar),
            \(smallChrome) {
              backdrop-filter: none;
            }
            """
        case .tinted:
            """
            /* habitat-chrome-material: tinted */
            \(sidebar) {
              backdrop-filter: none;
            }
            \(smallChrome) {
              backdrop-filter: blur(var(--habitat-tinted-blur-radius)) saturate(1.04);
            }
            """
        case .glass:
            """
            /* habitat-chrome-material: glass */
            \(sidebar) {
              backdrop-filter: none;
            }
            \(smallChrome) {
              backdrop-filter: blur(var(--habitat-blur-radius)) saturate(1.16);
              box-shadow: inset 0 1px 0 color-mix(in srgb, white 34%, transparent), 0 12px 30px color-mix(in srgb, var(--habitat-surface) 18%, transparent);
            }
            """
        }
        return treatment + """

        @media (max-width: 900px) {
          \(smallChrome) {
            backdrop-filter: none;
          }
        }
        """
    }

    static func styleTreatment(
        for family: HabitatThemeStyleFamily,
        profile: CompatibilityProfile
    ) -> String {
        let root = "html[data-codex-habitat-theme=\"1\"]"
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
        let shell = profile.selectors.appShell ?? "body"
        let stageSurfaces = [
            profile.selectors.mainSurface,
            profile.selectors.homeContent,
        ].compactMap { $0 }
        let transcriptSurfaces = [
            profile.selectors.threadScroll,
            profile.selectors.taskTranscript,
        ].compactMap { $0 }
        let contentSurfaces = [
            profile.selectors.homeSuggestions,
            profile.selectors.userMessageSurface,
            profile.selectors.messageSurface,
            profile.selectors.codeSurface,
            profile.selectors.stickyBand,
            profile.selectors.popover,
        ].compactMap { $0 } + (profile.selectors.toolSurfaces ?? [])
        let composerSurfaces = [
            Optional(profile.selectors.composer),
            profile.selectors.composerContext,
        ].compactMap { $0 }
        let selectedSurfaces = [
            profile.selectors.selectedNavigation,
        ].compactMap { $0 }
        let interruptionSurfaces = [
            profile.selectors.sidebarResizeChrome,
            profile.selectors.topFade,
            profile.selectors.bottomFade,
        ].compactMap { $0 }
        let interruptionRule = interruptionSurfaces.isEmpty ? "" : """
        \(scopedSelectors(interruptionSurfaces, root: root)) {
          background: transparent;
          box-shadow: none;
          backdrop-filter: none;
        }
        """
        let selectedSurfaceRule = selectedSurfaces.isEmpty ? "" : """
        \(scopedSelectors(selectedSurfaces, root: root)) {
          \(styleSelected(for: family))
          font-weight: 600;
        }
        """
        let homeActionRule = profile.selectors.homeSuggestions.map { suggestions in
            """
            /* habitat-surface: home-actions */
            \(root) \(suggestions) :where(button, [role="button"]) {
              color: var(--habitat-text);
              background-color: color-mix(in srgb, var(--habitat-panel-alt) 80%, transparent);
              \(styleHomeAction(for: family))
            }
            """
        } ?? ""
        return """
        /* habitat-style-family: \(family.rawValue) */

        /* habitat-surface: shell */
        \(root) \(shell) {
          accent-color: var(--habitat-accent);
          scrollbar-color: var(--habitat-accent) color-mix(in srgb, var(--habitat-panel-alt) 44%, transparent);
        }

        /* habitat-surface: sidebar */
        \(root) \(profile.selectors.sidebar) { \(declarations.sidebar) }

        /* habitat-surface: header */
        \(root) \(profile.selectors.header) { \(styleHeader(for: family)) }

        /* habitat-surface: stage */
        \(scopedSelectors(stageSurfaces, root: root)) { \(styleStage(for: family)) }

        /* habitat-surface: transcript */
        \(scopedSelectors(transcriptSurfaces, root: root)) {
          \(styleStage(for: family))
          scrollbar-color: var(--habitat-accent) color-mix(in srgb, var(--habitat-panel-alt) 44%, transparent);
        }

        /* habitat-surface: content */
        \(scopedSelectors(contentSurfaces, root: root)) { \(declarations.popover) }

        \(homeActionRule)

        /* habitat-surface: composer */
        \(scopedSelectors(composerSurfaces, root: root)) { \(declarations.composer) }

        /* habitat-surface: selected-navigation */
        \(selectedSurfaceRule)

        /* habitat-surface: fades-and-resize */
        \(interruptionRule)

        /* habitat-semantic-state: primary */
        \(root) button[type="submit"] { \(declarations.composer) }

        /* habitat-semantic-state: focus */
        \(root) :focus-visible {
          outline-style: \(styleFocus(for: family));
          outline-width: 2px;
          outline-offset: 2px;
        }

        /* habitat-semantic-state: selected */
        \(root) [aria-selected="true"],
        \(root) [aria-current],
        \(root) [aria-pressed="true"] { \(styleSelected(for: family)) }

        /* habitat-semantic-state: warning */
        \(root) :invalid:not([aria-invalid="true"]) {
          border-color: var(--habitat-attention);
          box-shadow: inset 3px 0 0 var(--habitat-attention);
        }

        /* habitat-semantic-state: destructive */
        \(root) [aria-invalid="true"] {
          border-color: var(--habitat-error);
          box-shadow: inset 3px 0 0 var(--habitat-error);
        }
        """
    }

    private static func styleHeader(for family: HabitatThemeStyleFamily) -> String {
        switch family {
        case .arcade:
            "border-bottom-width: 2px; box-shadow: inset 0 -3px 0 var(--habitat-secondary);"
        case .retroMessenger:
            "border-bottom-width: 1px; box-shadow: inset 0 1px 0 color-mix(in srgb, white 58%, transparent), inset 0 30px 0 color-mix(in srgb, var(--habitat-secondary) 24%, transparent);"
        case .greenChat:
            "border-bottom-width: 4px; border-bottom-color: var(--habitat-secondary); box-shadow: inset 0 1px 0 color-mix(in srgb, white 45%, transparent);"
        case .classicDesktop:
            "border-bottom: 2px outset var(--habitat-panel-alt); box-shadow: inset 1px 1px 0 white;"
        case .gameCinematic:
            "border-bottom-width: 2px; border-bottom-color: var(--habitat-attention); box-shadow: inset 0 -8px 18px color-mix(in srgb, black 18%, transparent);"
        case .cozyWorld:
            "border-bottom-width: 1px; box-shadow: inset 0 -4px 12px color-mix(in srgb, var(--habitat-secondary) 12%, transparent);"
        case .animeEnergy:
            "border-bottom-width: 3px; border-bottom-color: var(--habitat-highlight); box-shadow: inset 0 -7px 0 color-mix(in srgb, var(--habitat-accent) 16%, transparent);"
        case .fantasyAdventure:
            "border-bottom: 3px double color-mix(in srgb, var(--habitat-highlight) 62%, var(--habitat-accent)); box-shadow: inset 0 -5px 14px color-mix(in srgb, var(--habitat-secondary) 12%, transparent);"
        case .pixelWorld:
            "border-bottom-width: 3px; border-bottom-style: solid; box-shadow: inset 0 -3px 0 color-mix(in srgb, black 42%, transparent); image-rendering: pixelated;"
        }
    }

    private static func styleStage(for family: HabitatThemeStyleFamily) -> String {
        switch family {
        case .arcade:
            "border-inline-start: 2px solid color-mix(in srgb, var(--habitat-secondary) 58%, transparent);"
        case .retroMessenger:
            "box-shadow: inset 1px 0 0 color-mix(in srgb, white 44%, transparent);"
        case .greenChat:
            "box-shadow: inset 4px 0 0 color-mix(in srgb, var(--habitat-secondary) 34%, transparent);"
        case .classicDesktop:
            "outline: 1px solid var(--habitat-panel-alt); outline-offset: -1px;"
        case .gameCinematic:
            "box-shadow: inset 8px 0 24px color-mix(in srgb, black 16%, transparent);"
        case .cozyWorld:
            "border-radius: 8px 0 0 0; box-shadow: inset 4px 0 12px color-mix(in srgb, var(--habitat-secondary) 10%, transparent);"
        case .animeEnergy:
            "border-inline-start: 3px solid color-mix(in srgb, var(--habitat-highlight) 46%, transparent);"
        case .fantasyAdventure:
            "outline: 1px solid color-mix(in srgb, var(--habitat-highlight) 28%, transparent); outline-offset: -1px;"
        case .pixelWorld:
            "border-inline-start: 3px solid color-mix(in srgb, var(--habitat-text) 30%, transparent); image-rendering: pixelated;"
        }
    }

    private static func styleSelected(for family: HabitatThemeStyleFamily) -> String {
        switch family {
        case .arcade:
            "box-shadow: inset 3px 0 0 var(--habitat-highlight), inset 0 0 0 1px var(--habitat-secondary);"
        case .retroMessenger:
            "box-shadow: inset 3px 0 0 var(--habitat-accent), inset 0 1px 0 color-mix(in srgb, white 70%, transparent); border-radius: 5px;"
        case .greenChat:
            "box-shadow: inset 4px 0 0 var(--habitat-secondary); border-radius: 4px;"
        case .classicDesktop:
            "border: 2px inset var(--habitat-panel-alt); border-radius: 0; box-shadow: none;"
        case .gameCinematic:
            "box-shadow: inset 3px 0 0 var(--habitat-attention), 0 6px 18px color-mix(in srgb, black 18%, transparent); border-radius: 3px;"
        case .cozyWorld:
            "box-shadow: inset 3px 0 0 var(--habitat-accent); border-radius: 8px;"
        case .animeEnergy:
            "box-shadow: inset 4px 0 0 var(--habitat-highlight), 5px 5px 0 color-mix(in srgb, var(--habitat-secondary) 16%, transparent); border-radius: 2px;"
        case .fantasyAdventure:
            "box-shadow: inset 3px 0 0 var(--habitat-highlight), inset 0 0 12px color-mix(in srgb, var(--habitat-secondary) 12%, transparent); border-radius: 7px;"
        case .pixelWorld:
            "box-shadow: inset 3px 0 0 var(--habitat-highlight), 3px 3px 0 color-mix(in srgb, black 38%, transparent); border-radius: 0;"
        }
    }

    private static func styleHomeAction(for family: HabitatThemeStyleFamily) -> String {
        switch family {
        case .arcade:
            "border: 2px solid var(--habitat-secondary); border-radius: 4px; box-shadow: inset 0 -2px 0 color-mix(in srgb, var(--habitat-highlight) 48%, transparent);"
        case .retroMessenger:
            "border: 1px solid var(--habitat-accent); border-radius: 6px; box-shadow: inset 0 1px 0 color-mix(in srgb, white 76%, transparent), inset 0 -2px 0 color-mix(in srgb, var(--habitat-secondary) 24%, transparent);"
        case .greenChat:
            "border: 1px solid var(--habitat-secondary); border-inline-start: 4px solid var(--habitat-accent); border-radius: 5px; box-shadow: inset 0 1px 0 color-mix(in srgb, white 42%, transparent);"
        case .classicDesktop:
            "border: 2px outset var(--habitat-panel-alt); border-radius: 0; box-shadow: 2px 2px 0 color-mix(in srgb, black 48%, transparent);"
        case .gameCinematic:
            "border: 1px solid var(--habitat-attention); border-block-start: 3px solid var(--habitat-highlight); border-radius: 3px; box-shadow: 0 6px 16px color-mix(in srgb, black 24%, transparent);"
        case .cozyWorld:
            "border: 1px solid var(--habitat-secondary); border-radius: 8px; box-shadow: inset 0 1px 0 color-mix(in srgb, white 38%, transparent), 0 5px 14px color-mix(in srgb, var(--habitat-secondary) 12%, transparent);"
        case .animeEnergy:
            "border: 2px solid var(--habitat-highlight); border-block-end: 1px solid var(--habitat-secondary); border-radius: 2px; box-shadow: 4px 4px 0 color-mix(in srgb, var(--habitat-secondary) 20%, transparent);"
        case .fantasyAdventure:
            "border: 2px double color-mix(in srgb, var(--habitat-highlight) 72%, var(--habitat-accent)); border-radius: 7px; box-shadow: inset 0 0 10px color-mix(in srgb, var(--habitat-secondary) 12%, transparent);"
        case .pixelWorld:
            "border: 2px solid var(--habitat-text); border-radius: 0; box-shadow: 3px 3px 0 color-mix(in srgb, var(--habitat-text) 38%, transparent); image-rendering: pixelated;"
        }
    }

    private static func styleFocus(for family: HabitatThemeStyleFamily) -> String {
        switch family {
        case .arcade, .gameCinematic, .animeEnergy, .pixelWorld:
            "solid"
        case .retroMessenger, .greenChat, .cozyWorld:
            "auto"
        case .classicDesktop:
            "dotted"
        case .fantasyAdventure:
            "double"
        }
    }

    private func validate(_ appearance: BridgeThemeAppearance) throws {
        guard appearance.artFocus.x.isFinite, (0...1).contains(appearance.artFocus.x),
              appearance.artFocus.y.isFinite, (0...1).contains(appearance.artFocus.y)
        else {
            throw ThemeCompilationError.invalidAppearance("artFocus")
        }
        for (name, focus) in [
            ("homeArtFocus", appearance.homeArtFocus),
            ("taskArtFocus", appearance.taskArtFocus),
        ] where !focus.x.isFinite || !(0...1).contains(focus.x)
            || !focus.y.isFinite || !(0...1).contains(focus.y) {
            throw ThemeCompilationError.invalidAppearance(name)
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
            ("composerOpacity", appearance.composerOpacity),
        ] where !value.isFinite || !(0.40...1.0).contains(value) {
            throw ThemeCompilationError.invalidAppearance(name)
        }
        guard appearance.headerOpacity.isFinite,
              (0.0...1.0).contains(appearance.headerOpacity)
        else {
            throw ThemeCompilationError.invalidAppearance("headerOpacity")
        }
        for (name, value, range) in [
            ("homeArtScale", appearance.homeArtScale, 1.00...1.35),
            ("taskArtScale", appearance.taskArtScale, 1.00...1.35),
            ("taskSidebarOpacity", appearance.taskSidebarOpacity, 0.54...0.90),
            ("taskHeaderOpacity", appearance.taskHeaderOpacity, 0.54...0.90),
            ("homeContentOpacity", appearance.homeContentOpacity, 0.40...0.78),
            ("taskContentOpacity", appearance.taskContentOpacity, 0.60...0.84),
            ("homeContentWidth", appearance.homeContentWidth, 0.46...0.68),
            ("vignetteStrength", appearance.vignetteStrength, 0.00...0.70),
        ] where !value.isFinite || !range.contains(value) {
            throw ThemeCompilationError.invalidAppearance(name)
        }
    }

    private static func safeScrim(for safeSide: HabitatThemeSafeSide) -> String {
        let chromeWash = "linear-gradient(to bottom, color-mix(in srgb, var(--habitat-surface) 22%, transparent) 0%, transparent 14% 78%, color-mix(in srgb, var(--habitat-surface) 30%, transparent) 100%)"
        let directional = switch safeSide {
        case .leading:
            "linear-gradient(to right, color-mix(in srgb, var(--habitat-surface) var(--habitat-vignette-strength), transparent) 0%, transparent 58%)"
        case .trailing:
            "linear-gradient(to left, color-mix(in srgb, var(--habitat-surface) var(--habitat-vignette-strength), transparent) 0%, transparent 58%)"
        case .center:
            "radial-gradient(ellipse at center, color-mix(in srgb, var(--habitat-surface) var(--habitat-vignette-strength), transparent) 0 24%, transparent 74%)"
        case .none:
            "linear-gradient(transparent, transparent)"
        }
        return "\(chromeWash), \(directional)"
    }

    private static func taskReadingScrim(for safeSide: HabitatThemeSafeSide) -> String {
        let chromeWash = "linear-gradient(to bottom, color-mix(in srgb, var(--habitat-surface) 18%, transparent) 0%, transparent 15% 72%, color-mix(in srgb, var(--habitat-surface) 34%, transparent) 100%)"
        let directional = switch safeSide {
        case .leading:
            "linear-gradient(to right, color-mix(in srgb, var(--habitat-surface) var(--habitat-task-content-opacity), transparent) 0 24%, color-mix(in srgb, var(--habitat-surface) 30%, transparent) 52%, transparent 78%)"
        case .trailing:
            "linear-gradient(to left, color-mix(in srgb, var(--habitat-surface) var(--habitat-task-content-opacity), transparent) 0 24%, color-mix(in srgb, var(--habitat-surface) 30%, transparent) 52%, transparent 78%)"
        case .center:
            "radial-gradient(ellipse at center, color-mix(in srgb, var(--habitat-surface) var(--habitat-task-content-opacity), transparent) 0 24%, color-mix(in srgb, var(--habitat-surface) 30%, transparent) 56%, transparent 82%)"
        case .none:
            "linear-gradient(color-mix(in srgb, var(--habitat-surface) var(--habitat-task-content-opacity), transparent), color-mix(in srgb, var(--habitat-surface) var(--habitat-task-content-opacity), transparent))"
        }
        return "\(chromeWash), \(directional)"
    }

    private static func scopedSelectors(_ selectors: [String], root: String) -> String {
        var seen: Set<String> = []
        return selectors.compactMap { selector in
            guard seen.insert(selector).inserted else { return nil }
            return "\(root) \(selector)"
        }.joined(separator: ",\n")
    }

    static func bannerArtworkBottomInset(focusY: Double, scale: Double) -> Double {
        let localVisibleBottom = bannerArtworkLocalPosition(
            focusY: focusY,
            scale: scale,
            transformedPosition: 0.52
        )
        return min(max(1 - localVisibleBottom, 0), 1)
    }

    static func bannerArtworkLocalPosition(
        focusY: Double,
        scale: Double,
        transformedPosition: Double
    ) -> Double {
        guard focusY.isFinite, scale.isFinite, scale > 0,
              transformedPosition.isFinite
        else {
            return transformedPosition
        }
        return min(max(focusY + (transformedPosition - focusY) / scale, 0), 1)
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
