public enum HabitatThemeSafeSide: String, Codable, CaseIterable, Sendable {
    case leading
    case trailing
}

public enum HabitatThemeStyleFamily: String, Codable, CaseIterable, Sendable {
    case arcade
    case retroMessenger
    case greenChat
    case classicDesktop
    case gameCinematic
}

public struct HabitatThemePalette: Codable, Equatable, Sendable {
    public let surface: String
    public let panel: String
    public let panelAlt: String
    public let text: String
    public let mutedText: String
    public let accent: String
    public let secondary: String
    public let highlight: String
    public let attention: String
    public let error: String

    public init(
        surface: String,
        panel: String,
        panelAlt: String,
        text: String,
        mutedText: String,
        accent: String,
        secondary: String,
        highlight: String,
        attention: String,
        error: String
    ) {
        self.surface = surface
        self.panel = panel
        self.panelAlt = panelAlt
        self.text = text
        self.mutedText = mutedText
        self.accent = accent
        self.secondary = secondary
        self.highlight = highlight
        self.attention = attention
        self.error = error
    }
}

public struct BuiltInThemeDefinition: Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let symbol: String
    public let palette: HabitatThemePalette
    public let artFocusX: Double
    public let artFocusY: Double
    public let safeSide: HabitatThemeSafeSide
    public let styleFamily: HabitatThemeStyleFamily

    public init(
        id: String,
        name: String,
        detail: String,
        symbol: String,
        palette: HabitatThemePalette,
        artFocusX: Double,
        artFocusY: Double,
        safeSide: HabitatThemeSafeSide,
        styleFamily: HabitatThemeStyleFamily
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.palette = palette
        self.artFocusX = artFocusX
        self.artFocusY = artFocusY
        self.safeSide = safeSide
        self.styleFamily = styleFamily
    }
}

public enum BuiltInThemeCatalog {
    public static let all: [BuiltInThemeDefinition] = [
        theme(
            "workbench", "Workbench Turbo", "Electric tools and hot metal panels.",
            "wrench.and.screwdriver.fill", "#171A21", "#242936", "#30384A", "#F7FBFF",
            "#AEB9C9", "#FF7A18", "#18D6C8", "#FFE04B", "#FFB020", "#FF4058",
            0.78, 0.48, .leading, .gameCinematic
        ),
        theme(
            "night-shift", "Neon Night Shift", "Midnight control room in electric violet.",
            "moon.stars.fill", "#100D1E", "#21173A", "#302052", "#FFF7FF",
            "#C9B7DB", "#B94DFF", "#00E7F2", "#FF4FCB", "#FFD34E", "#FF496C",
            0.76, 0.42, .leading, .gameCinematic
        ),
        theme(
            "arcade-signal", "Arcade Overdrive", "Cabinet lights and score-chasing energy.",
            "gamecontroller.fill", "#121023", "#251A46", "#38225F", "#FFF8F0",
            "#C7B8D8", "#FF2D95", "#2DE2E6", "#FFF13D", "#FF9F1C", "#FF3B55",
            0.74, 0.50, .leading, .arcade
        ),
        theme(
            "quiet-garden", "Pixel Meadow", "Bright pixel flora and fresh open air.",
            "leaf.fill", "#12251D", "#21432E", "#32613D", "#F5FFE8",
            "#B8D5AF", "#72E06A", "#35C9D0", "#FFF06A", "#FFB43A", "#FF5364",
            0.78, 0.46, .leading, .arcade
        ),
        theme(
            "retro-messenger", "Retro Messenger 2007", "Glossy blue desktop chat nostalgia.",
            "bubble.left.and.bubble.right.fill", "#DCEEFF", "#F5FAFF", "#C7E3FF", "#102A43",
            "#526C82", "#1687E8", "#55B8FF", "#FFF06A", "#FF9D2E", "#E43F5A",
            0.80, 0.42, .leading, .retroMessenger
        ),
        theme(
            "green-chat-desk", "Green Chat Desktop", "Forest rails and mint message panes.",
            "message.fill", "#E7F8EC", "#F8FFF9", "#BDE9C9", "#113B25",
            "#4A7059", "#20A45B", "#79D98C", "#E8F65B", "#F5A623", "#D83A4E",
            0.77, 0.48, .leading, .greenChat
        ),
        theme(
            "cyber-cafe", "Cyber Cafe Neon", "Magenta and cyan after-hours terminals.",
            "desktopcomputer", "#100B1C", "#25123A", "#103B46", "#FFF5FF",
            "#CBB2D2", "#FF2EB8", "#00E4E8", "#DFFF37", "#FFB000", "#FF405D",
            0.77, 0.44, .leading, .retroMessenger
        ),
        theme(
            "candy-combo", "Candy Combo", "Glossy candy lanes and combo flashes.",
            "sparkles", "#32152E", "#552047", "#74305A", "#FFF8FC",
            "#E8BED7", "#FF5FB2", "#45D9C5", "#FFF06D", "#FFB347", "#E83E62",
            0.73, 0.48, .leading, .arcade
        ),
        theme(
            "crimson-mecha", "Crimson Mecha", "Armored bays under warning-red light.",
            "shield.lefthalf.filled", "#1D1114", "#32181D", "#4A2025", "#FFF6F2",
            "#C9AAA7", "#F33E4D", "#4CC9C0", "#FFD34D", "#FF8A24", "#FF3045",
            0.79, 0.48, .leading, .gameCinematic
        ),
        theme(
            "win95-workbench", "Win95 Workbench", "Pixel-sharp controls and workshop gray.",
            "macwindow", "#C0C0C0", "#E7E7E7", "#9C9C9C", "#101010",
            "#4D4D4D", "#0000A8", "#008080", "#FFFF00", "#D66A00", "#C00024",
            0.78, 0.45, .leading, .classicDesktop
        ),
        theme(
            "gold-rush", "Gold Rush", "Sunlit machinery and treasure-run momentum.",
            "crown.fill", "#21180D", "#3D2B12", "#5A3E17", "#FFF9E8",
            "#D7C29A", "#F2B632", "#25B7A5", "#FFF176", "#FF8B24", "#E8473F",
            0.76, 0.46, .leading, .gameCinematic
        ),
        theme(
            "aqua-pulse", "Aqua Pulse", "Clear water circuits and kinetic light.",
            "wave.3.right.circle.fill", "#092126", "#123B42", "#19535B", "#EDFFFF",
            "#A4D3D5", "#17C9C3", "#5AA9FF", "#D6FF57", "#FFB13B", "#FF4F64",
            0.76, 0.48, .leading, .arcade
        ),
    ]

    public static func definition(id: String) -> BuiltInThemeDefinition? {
        all.first { $0.id == id }
    }

    private static func theme(
        _ id: String,
        _ name: String,
        _ detail: String,
        _ symbol: String,
        _ surface: String,
        _ panel: String,
        _ panelAlt: String,
        _ text: String,
        _ mutedText: String,
        _ accent: String,
        _ secondary: String,
        _ highlight: String,
        _ attention: String,
        _ error: String,
        _ artFocusX: Double,
        _ artFocusY: Double,
        _ safeSide: HabitatThemeSafeSide,
        _ styleFamily: HabitatThemeStyleFamily
    ) -> BuiltInThemeDefinition {
        BuiltInThemeDefinition(
            id: id,
            name: name,
            detail: detail,
            symbol: symbol,
            palette: HabitatThemePalette(
                surface: surface,
                panel: panel,
                panelAlt: panelAlt,
                text: text,
                mutedText: mutedText,
                accent: accent,
                secondary: secondary,
                highlight: highlight,
                attention: attention,
                error: error
            ),
            artFocusX: artFocusX,
            artFocusY: artFocusY,
            safeSide: safeSide,
            styleFamily: styleFamily
        )
    }
}
