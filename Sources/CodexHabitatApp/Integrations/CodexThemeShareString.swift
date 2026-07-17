import Foundation

enum CodexThemeVariant: String, CaseIterable, Codable, Identifiable {
    case light
    case dark

    var id: String { rawValue }
}

enum CodexThemeShareString {
    private static let prefix = "codex-theme-v1:"

    static func make(
        theme: HabitatThemeDescriptor,
        variant: CodexThemeVariant
    ) -> String {
        let document = Document(
            codeThemeId: "codex",
            theme: Theme(
                accent: theme.accentHex,
                contrast: 50,
                fonts: Fonts(code: nil, ui: nil),
                ink: theme.textHex,
                opaqueWindows: true,
                semanticColors: SemanticColors(
                    diffAdded: theme.accentHex,
                    diffRemoved: theme.errorHex,
                    skill: theme.attentionHex
                ),
                surface: theme.surfaceHex
            ),
            variant: variant
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(document),
              let payload = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return prefix + payload
    }

    static func suggestedVariant(for theme: HabitatThemeDescriptor) -> CodexThemeVariant {
        guard let components = rgb(theme.surfaceHex) else { return .dark }
        let luminance = 0.2126 * components.red
            + 0.7152 * components.green
            + 0.0722 * components.blue
        return luminance >= 0.5 ? .light : .dark
    }

    private static func rgb(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        let value = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard value.count >= 6,
              let red = Int(value.prefix(2), radix: 16),
              let green = Int(value.dropFirst(2).prefix(2), radix: 16),
              let blue = Int(value.dropFirst(4).prefix(2), radix: 16)
        else {
            return nil
        }
        return (Double(red) / 255, Double(green) / 255, Double(blue) / 255)
    }

    private struct Document: Codable {
        let codeThemeId: String
        let theme: Theme
        let variant: CodexThemeVariant
    }

    private struct Theme: Codable {
        let accent: String
        let contrast: Int
        let fonts: Fonts
        let ink: String
        let opaqueWindows: Bool
        let semanticColors: SemanticColors
        let surface: String
    }

    private struct Fonts: Codable {
        let code: String?
        let ui: String?

        private enum CodingKeys: CodingKey {
            case code
            case ui
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(code, forKey: .code)
            try container.encode(ui, forKey: .ui)
        }
    }

    private struct SemanticColors: Codable {
        let diffAdded: String
        let diffRemoved: String
        let skill: String
    }
}
