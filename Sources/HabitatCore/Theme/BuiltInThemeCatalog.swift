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

public struct BuiltInThemeTreatment: Equatable, Sendable {
    public let homeMode: HabitatThemeHomeMode
    public let taskMode: HabitatThemeTaskMode
    public let chromeMaterial: HabitatThemeChromeMaterial
    public let homeStrength: Double
    public let taskStrength: Double
    public let sidebarOpacity: Double
    public let headerOpacity: Double
    public let composerOpacity: Double
    public let blurRadius: Double
    public let density: HabitatThemeDensity

    public init(
        homeMode: HabitatThemeHomeMode,
        taskMode: HabitatThemeTaskMode,
        chromeMaterial: HabitatThemeChromeMaterial,
        homeStrength: Double,
        taskStrength: Double,
        sidebarOpacity: Double,
        headerOpacity: Double,
        composerOpacity: Double,
        blurRadius: Double,
        density: HabitatThemeDensity
    ) {
        self.homeMode = homeMode
        self.taskMode = taskMode
        self.chromeMaterial = chromeMaterial
        self.homeStrength = homeStrength
        self.taskStrength = taskStrength
        self.sidebarOpacity = sidebarOpacity
        self.headerOpacity = headerOpacity
        self.composerOpacity = composerOpacity
        self.blurRadius = blurRadius
        self.density = density
    }
}

public struct BuiltInThemeDefinition: Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let symbol: String
    public let palette: HabitatThemePalette
    public let category: HabitatThemeCategory
    public let artFocusX: Double
    public let artFocusY: Double
    public let safeSide: HabitatThemeSafeSide
    public let styleFamily: HabitatThemeStyleFamily
    public let treatment: BuiltInThemeTreatment?

    public init(
        id: String,
        name: String,
        detail: String,
        symbol: String,
        palette: HabitatThemePalette,
        category: HabitatThemeCategory,
        artFocusX: Double,
        artFocusY: Double,
        safeSide: HabitatThemeSafeSide,
        styleFamily: HabitatThemeStyleFamily,
        treatment: BuiltInThemeTreatment? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.palette = palette
        self.category = category
        self.artFocusX = artFocusX
        self.artFocusY = artFocusY
        self.safeSide = safeSide
        self.styleFamily = styleFamily
        self.treatment = treatment
    }

    public func appearance(background: String) -> HabitatThemeAppearance {
        HabitatThemeAppearance(
            category: category,
            styleFamily: styleFamily,
            background: background,
            artFocus: HabitatThemeFocalPoint(x: artFocusX, y: artFocusY),
            safeSide: safeSide,
            backgroundStrength: 0.42,
            panelOpacity: 0.88,
            blurRadius: treatment?.blurRadius ?? 10,
            density: treatment?.density ?? .comfortable,
            homeMode: treatment?.homeMode,
            taskMode: treatment?.taskMode,
            chromeMaterial: treatment?.chromeMaterial,
            homeStrength: treatment?.homeStrength,
            taskStrength: treatment?.taskStrength,
            sidebarOpacity: treatment?.sidebarOpacity,
            headerOpacity: treatment?.headerOpacity,
            composerOpacity: treatment?.composerOpacity
        )
    }
}

public enum BuiltInThemeCatalog {
    public static let all: [BuiltInThemeDefinition] = [
        theme(
            "workbench", "Workbench Turbo", "Electric tools and hot metal panels.",
            "wrench.and.screwdriver.fill", "#171A21", "#242936", "#30384A", "#F7FBFF",
            "#AEB9C9", "#FF7A18", "#18D6C8", "#FFE04B", "#FFB020", "#FF4058",
            0.78, 0.48, .leading, .gameCinematic, .utility,
            treatment(
                .immersive, .ambient, .tinted,
                0.72, 0.30, 0.92, 0.66, 0.90, 8, .comfortable
            )
        ),
        theme(
            "night-shift", "Neon Night Shift", "Midnight control room in electric violet.",
            "moon.stars.fill", "#100D1E", "#21173A", "#302052", "#FFF7FF",
            "#C9B7DB", "#B94DFF", "#00E7F2", "#FF4FCB", "#FFD34E", "#FF496C",
            0.76, 0.42, .leading, .gameCinematic, .dark
        ),
        theme(
            "arcade-signal", "Arcade Overdrive", "Cabinet lights and score-chasing energy.",
            "gamecontroller.fill", "#121023", "#251A46", "#38225F", "#FFF8F0",
            "#C7B8D8", "#FF2D95", "#2DE2E6", "#FFF13D", "#FF9F1C", "#FF3B55",
            0.74, 0.50, .leading, .arcade, .game,
            treatment(
                .immersive, .banner, .solid,
                0.76, 0.40, 0.90, 0.64, 0.94, 4, .compact
            )
        ),
        theme(
            "quiet-garden", "Pixel Meadow", "Bright pixel flora and fresh open air.",
            "leaf.fill", "#12251D", "#21432E", "#32613D", "#F5FFE8",
            "#B8D5AF", "#72E06A", "#35C9D0", "#FFF06A", "#FFB43A", "#FF5364",
            0.78, 0.46, .leading, .cozyWorld, .cozy,
            treatment(
                .quiet, .off, .glass,
                0.48, 0.10, 0.72, 0.64, 0.78, 16, .comfortable
            )
        ),
        theme(
            "retro-messenger", "Retro Messenger 2007", "Glossy blue desktop chat nostalgia.",
            "bubble.left.and.bubble.right.fill", "#DCEEFF", "#F5FAFF", "#C7E3FF", "#102A43",
            "#526C82", "#1687E8", "#55B8FF", "#FFF06A", "#FF9D2E", "#E43F5A",
            0.80, 0.42, .leading, .retroMessenger, .nostalgia,
            treatment(
                .framed, .banner, .glass,
                0.64, 0.34, 0.78, 0.72, 0.84, 14, .compact
            )
        ),
        theme(
            "green-chat-desk", "Green Chat Desktop", "Forest rails and mint message panes.",
            "message.fill", "#E7F8EC", "#F8FFF9", "#BDE9C9", "#113B25",
            "#4A7059", "#20A45B", "#79D98C", "#E8F65B", "#F5A623", "#D83A4E",
            0.77, 0.48, .leading, .greenChat, .chat
        ),
        theme(
            "cyber-cafe", "Cyber Cafe Neon", "Magenta and cyan after-hours terminals.",
            "desktopcomputer", "#100B1C", "#25123A", "#103B46", "#FFF5FF",
            "#CBB2D2", "#FF2EB8", "#00E4E8", "#DFFF37", "#FFB000", "#FF405D",
            0.77, 0.44, .leading, .retroMessenger, .nostalgia
        ),
        theme(
            "candy-combo", "Candy Combo", "Glossy candy lanes and combo flashes.",
            "sparkles", "#32152E", "#552047", "#74305A", "#FFF8FC",
            "#E8BED7", "#FF5FB2", "#45D9C5", "#FFF06D", "#FFB347", "#E83E62",
            0.73, 0.48, .leading, .arcade, .game
        ),
        theme(
            "crimson-mecha", "Crimson Mecha", "Armored bays under warning-red light.",
            "shield.lefthalf.filled", "#1D1114", "#32181D", "#4A2025", "#FFF6F2",
            "#C9AAA7", "#F33E4D", "#4CC9C0", "#FFD34D", "#FF8A24", "#FF3045",
            0.79, 0.48, .leading, .gameCinematic, .game
        ),
        theme(
            "win95-workbench", "Win95 Workbench", "Pixel-sharp controls and workshop gray.",
            "macwindow", "#C0C0C0", "#E7E7E7", "#9C9C9C", "#101010",
            "#4D4D4D", "#0000A8", "#008080", "#FFFF00", "#D66A00", "#C00024",
            0.78, 0.45, .leading, .classicDesktop, .classic
        ),
        theme(
            "gold-rush", "Gold Rush", "Sunlit machinery and treasure-run momentum.",
            "crown.fill", "#21180D", "#3D2B12", "#5A3E17", "#FFF9E8",
            "#D7C29A", "#F2B632", "#25B7A5", "#FFF176", "#FF8B24", "#E8473F",
            0.76, 0.46, .leading, .gameCinematic, .game
        ),
        theme(
            "aqua-pulse", "Aqua Pulse", "Clear water circuits and kinetic light.",
            "wave.3.right.circle.fill", "#092126", "#123B42", "#19535B", "#EDFFFF",
            "#A4D3D5", "#17C9C3", "#5AA9FF", "#D6FF57", "#FFB13B", "#FF4F64",
            0.76, 0.48, .leading, .arcade, .game
        ),
        theme(
            "harvest-homestead", "Harvest Homestead", "Orchards and bright morning fields.",
            "sun.max.fill", "#193120", "#2D5332", "#426F3D", "#FFFBE9",
            "#C5D7B0", "#F0A52B", "#68C75A", "#FFE86A", "#FFB037", "#D94B4B",
            0.78, 0.44, .leading, .cozyWorld, .cozy
        ),
        theme(
            "solar-ki-arena", "Solar Ki Arena", "Rocky competition grounds charged with sunlight.",
            "sun.and.horizon.fill", "#1E243A", "#303B62", "#4D4E78", "#FFF8E8",
            "#C5C8DA", "#FF8A21", "#2679FF", "#FFE04F", "#FFB42D", "#E84545",
            0.80, 0.42, .leading, .animeEnergy, .animeEnergy
        ),
        theme(
            "moonlit-shinobi", "Moonlit Shinobi", "Indigo rooftops and silent crimson signals.",
            "moon.fill", "#10182E", "#1C2A4B", "#33416A", "#F2F5FF",
            "#AEB9D0", "#5D72F2", "#E53E56", "#92F4FF", "#F5B942", "#FF405D",
            0.78, 0.38, .leading, .animeEnergy, .animeEnergy
        ),
        theme(
            "grand-ocean-crew", "Grand Ocean Crew", "Open water charts and sunlit sails.",
            "sailboat.fill", "#092B3C", "#124C63", "#176D7C", "#F5FFF7",
            "#A8D4D2", "#1CB8D1", "#F09C32", "#FFE065", "#FFB13B", "#E64D4D",
            0.76, 0.46, .leading, .fantasyAdventure, .adventure
        ),
        theme(
            "elemental-companions", "Elemental Companions", "Friendly habitats shaped by earth, water, and light.",
            "circle.hexagongrid.fill", "#18302E", "#28514A", "#3E6A59", "#F5FFF1",
            "#B7D4C5", "#48C887", "#5AA9FF", "#FFD85A", "#F2A13A", "#E74D5B",
            0.79, 0.47, .leading, .cozyWorld, .cozyAdventure
        ),
        theme(
            "walled-vanguard", "Walled Vanguard", "Monumental ramparts under a disciplined dawn.",
            "building.columns.fill", "#20252A", "#343B41", "#4D555B", "#F7F4EB",
            "#BFC3C1", "#D65A42", "#4D8A91", "#F2D06B", "#E69A38", "#D83B48",
            0.80, 0.43, .leading, .gameCinematic, .cinematic
        ),
        theme(
            "arcane-academy", "Arcane Academy", "Jewel-tone bookshelves and constellation light.",
            "books.vertical.fill", "#21142E", "#3B2352", "#57346F", "#FFF7F4",
            "#D0B8D4", "#9C5CFF", "#26C6B7", "#FFD95A", "#E99B38", "#E14662",
            0.78, 0.40, .leading, .fantasyAdventure, .fantasy
        ),
        theme(
            "hero-training-campus", "Hero Training Campus", "Graphic training lanes with primary-color momentum.",
            "figure.run", "#17223A", "#263A62", "#3B527B", "#FFF9EE",
            "#B8C5D8", "#247CFF", "#F04452", "#FFE24B", "#F3A32E", "#E9384F",
            0.76, 0.47, .leading, .animeEnergy, .animeEnergy
        ),
        theme(
            "nebula-vanguard", "Nebula Vanguard", "A deep-space command deck in red and blue light.",
            "sparkle.magnifyingglass", "#0B1325", "#172A48", "#293C5B", "#F2F7FF",
            "#AAB9CB", "#337DFF", "#F0445B", "#6DEBFF", "#F2B13A", "#FF3C55",
            0.79, 0.42, .leading, .gameCinematic, .cinematic
        ),
        theme(
            "spirit-lantern-town", "Spirit Lantern Town", "Hand-painted streets warmed by quiet lanterns.",
            "lamp.desk.fill", "#23302E", "#3D5148", "#5D6A55", "#FFF8E8",
            "#D3C9AB", "#E9783F", "#46A38C", "#FFD66B", "#F19B3A", "#D94C51",
            0.78, 0.42, .leading, .cozyWorld, .storybook
        ),
        theme(
            "block-frontier", "Block Frontier", "Voxel valleys and crisp inventory rhythms.",
            "cube.fill", "#203126", "#36523B", "#51704C", "#F7FFE9",
            "#BCD0AC", "#58B957", "#4CA6E8", "#F4DF55", "#D99636", "#D94A4A",
            0.77, 0.48, .leading, .pixelWorld, .pixelGame
        ),
        theme(
            "turbo-striker", "Turbo Striker", "Floodlit stadium energy with cyan-lime signals.",
            "soccerball", "#101D29", "#1D3647", "#2B5160", "#F3FFFF",
            "#A9C8CD", "#00CFE3", "#9BE33A", "#FFF24F", "#F1A632", "#EE4056",
            0.76, 0.44, .leading, .arcade, .sports
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
        _ styleFamily: HabitatThemeStyleFamily,
        _ category: HabitatThemeCategory,
        _ treatment: BuiltInThemeTreatment? = nil
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
            category: category,
            artFocusX: artFocusX,
            artFocusY: artFocusY,
            safeSide: safeSide,
            styleFamily: styleFamily,
            treatment: treatment
        )
    }

    private static func treatment(
        _ homeMode: HabitatThemeHomeMode,
        _ taskMode: HabitatThemeTaskMode,
        _ chromeMaterial: HabitatThemeChromeMaterial,
        _ homeStrength: Double,
        _ taskStrength: Double,
        _ sidebarOpacity: Double,
        _ headerOpacity: Double,
        _ composerOpacity: Double,
        _ blurRadius: Double,
        _ density: HabitatThemeDensity
    ) -> BuiltInThemeTreatment {
        BuiltInThemeTreatment(
            homeMode: homeMode,
            taskMode: taskMode,
            chromeMaterial: chromeMaterial,
            homeStrength: homeStrength,
            taskStrength: taskStrength,
            sidebarOpacity: sidebarOpacity,
            headerOpacity: headerOpacity,
            composerOpacity: composerOpacity,
            blurRadius: blurRadius,
            density: density
        )
    }
}
