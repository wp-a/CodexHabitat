import Foundation

struct BridgeThemeTokens: Codable, Equatable, Sendable {
    let surface: String
    let text: String
    let accent: String
    let attention: String
    let error: String

    static let workbench = BridgeThemeTokens(
        surface: "#F4F7F8",
        text: "#172126",
        accent: "#0F8B8D",
        attention: "#D97706",
        error: "#D64545"
    )
}

struct BridgeTheme: Codable, Equatable, Sendable {
    let tokens: BridgeThemeTokens
    let artBlobURL: String?
}

extension BridgeTheme {
    static func builtIn(id: String) -> BridgeTheme? {
        let tokens: BridgeThemeTokens
        switch id {
        case "workbench":
            tokens = .workbench
        case "night-shift":
            tokens = BridgeThemeTokens(
                surface: "#171A1D",
                text: "#F1F5F6",
                accent: "#2DD4BF",
                attention: "#F59E0B",
                error: "#FB7185"
            )
        case "arcade-signal":
            tokens = BridgeThemeTokens(
                surface: "#14151A",
                text: "#F7F7F2",
                accent: "#2D8CFF",
                attention: "#FFD23F",
                error: "#FF4D5A"
            )
        case "quiet-garden":
            tokens = BridgeThemeTokens(
                surface: "#F5F8F4",
                text: "#203127",
                accent: "#3D8B63",
                attention: "#C86A45",
                error: "#C4455D"
            )
        default:
            return nil
        }
        return BridgeTheme(tokens: tokens, artBlobURL: nil)
    }
}

enum ThemeCompilationError: Error, Equatable {
    case unknownThemeField(String)
    case invalidColorToken(String)
    case invalidArtBlobURL
    case unsafeTemplate
    case missingPlaceholder(String)
}

struct BridgeThemeDecoder {
    func decode(_ data: Data) throws -> BridgeTheme {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ThemeCompilationError.unknownThemeField("document")
        }
        let allowed: Set<String> = ["tokens", "artBlobURL"]
        let unknown = Set(object.keys).subtracting(allowed)
        if unknown.contains("selectors") {
            throw ThemeCompilationError.unknownThemeField("selectors")
        }
        if let field = unknown.sorted().first {
            throw ThemeCompilationError.unknownThemeField(field)
        }
        if let tokenObject = object["tokens"] as? [String: Any] {
            let tokenAllowed: Set<String> = [
                "surface", "text", "accent", "attention", "error",
            ]
            if let field = Set(tokenObject.keys).subtracting(tokenAllowed).sorted().first {
                throw ThemeCompilationError.unknownThemeField("tokens.\(field)")
            }
        }
        return try JSONDecoder().decode(BridgeTheme.self, from: data)
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
        guard let url = Bundle.module.url(
            forResource: "codex-theme-template",
            withExtension: "css",
            subdirectory: "Resources"
        ) else {
            throw ThemeCompilationError.unsafeTemplate
        }
        return try ThemeCompiler(template: String(contentsOf: url, encoding: .utf8))
    }

    func compile(theme: BridgeTheme, profile: CompatibilityProfile) throws -> String {
        let colors: [(String, String)] = [
            ("surface", theme.tokens.surface),
            ("text", theme.tokens.text),
            ("accent", theme.tokens.accent),
            ("attention", theme.tokens.attention),
            ("error", theme.tokens.error),
        ]
        for (name, color) in colors where color.range(
            of: "^#[0-9A-Fa-f]{6}$",
            options: .regularExpression
        ) == nil {
            throw ThemeCompilationError.invalidColorToken(name)
        }
        let artBackground: String
        if let artBlobURL = theme.artBlobURL {
            guard artBlobURL.range(
                of: "^blob:app://[A-Za-z0-9._/-]+$",
                options: .regularExpression
            ) != nil else {
                throw ThemeCompilationError.invalidArtBlobURL
            }
            artBackground = "url(\"\(artBlobURL)\")"
        } else {
            artBackground = "none"
        }

        var result = template
        let replacements = [
            "surface": theme.tokens.surface,
            "text": theme.tokens.text,
            "accent": theme.tokens.accent,
            "attention": theme.tokens.attention,
            "error": theme.tokens.error,
            "art-background": artBackground,
            "sidebar": profile.selectors.sidebar,
            "main": profile.selectors.mainSurface,
            "composer": profile.selectors.composer,
            "thread": profile.selectors.threadScroll,
            "popover": profile.selectors.popover,
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
}
